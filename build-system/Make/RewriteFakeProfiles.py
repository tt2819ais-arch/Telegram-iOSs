#!/usr/bin/env python3
"""Rewrite fake-codesigning provisioning profiles to use a custom bundle_id.

The fake-codesigning profiles bundled with the repo are pre-baked for the
official Telegram bundle id (``ph.telegra.Telegraph``). When a fork wants to
use its own bundle id we need matching profiles, otherwise
``copy_profiles_from_directory`` (in ``BuildConfiguration.py``) skips every
profile because their ``application-identifier`` no longer starts with
``team_id + '.' + bundle_id``.

This script:

* extracts the plist from each ``.mobileprovision`` (CMS-wrapped) file,
* rewrites ``application-identifier``, App Group ids, iCloud container ids
  and other entitlement strings that reference the original bundle id,
* re-encodes the modified plist as a CMS-wrapped DER blob signed with the
  bundled fake self-signed certificate.

The output is intended for fake-signing builds that get re-signed by tools
like Esign/Sideloadly/AltStore on install, so signature validity does not
matter — only that the CMS structure parses and the entitlements match the
new bundle_id.
"""

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile


def _run(args, **kwargs):
    """Run ``args`` and surface the captured stderr if it fails.

    The default ``subprocess.run(check=True)`` raises
    ``CalledProcessError`` with no body, which makes CI logs unhelpful.
    """
    proc = subprocess.run(args, capture_output=True, **kwargs)
    if proc.returncode != 0:
        sys.stderr.write('Command failed: {}\n'.format(' '.join(args)))
        if proc.stdout:
            sys.stderr.write('stdout: {}\n'.format(proc.stdout.decode('utf-8', 'replace')))
        if proc.stderr:
            sys.stderr.write('stderr: {}\n'.format(proc.stderr.decode('utf-8', 'replace')))
        raise subprocess.CalledProcessError(proc.returncode, args, proc.stdout, proc.stderr)
    return proc


def _try_run(args):
    """Like ``_run`` but returns False instead of raising on failure."""
    proc = subprocess.run(args, capture_output=True)
    return proc.returncode == 0


def _rewrite_string(value: str, original_bundle_id: str, new_bundle_id: str) -> str:
    return value.replace(original_bundle_id, new_bundle_id)


def _rewrite_entitlements(entitlements: dict, original_bundle_id: str, new_bundle_id: str) -> dict:
    """Rewrite every entitlement string that references the original bundle id.

    This walks every key in the entitlements dict (including nested
    arrays) and replaces occurrences of ``original_bundle_id`` with
    ``new_bundle_id``.  Keys that we know never reference the bundle id
    (e.g. ``com.apple.developer.in-app-payments``) are left untouched
    because the merchant identifiers there belong to Telegram and would
    not be valid for a fork anyway.
    """
    skip_keys = {
        # Apple Pay merchant ids belong to the official Telegram apps and
        # should be removed for forks because Esign/AltStore strips the
        # in-app-payments entitlement on re-sign anyway.
        'com.apple.developer.in-app-payments',
    }
    result = {}
    for key, value in entitlements.items():
        if key in skip_keys:
            # Drop the entitlement entirely; forks have no merchant ids.
            continue
        if isinstance(value, str):
            result[key] = _rewrite_string(value, original_bundle_id, new_bundle_id)
        elif isinstance(value, list):
            result[key] = [
                _rewrite_string(item, original_bundle_id, new_bundle_id) if isinstance(item, str) else item
                for item in value
            ]
        else:
            result[key] = value
    return result


def _extract_p12(p12_path: str, work_dir: str) -> tuple:
    """Extract the X.509 cert and PEM private key from the bundled p12.

    The bundled ``SelfSigned.p12`` uses an empty passphrase (this matches
    how ``ImportCertificates.py`` imports it).

    OpenSSL 3.x needs ``-legacy`` for older p12 encryption (RC2-40), but
    the LibreSSL build shipped in ``/usr/bin/openssl`` on macOS does not
    accept ``-legacy``.  We probe for support first.
    """
    cert_path = os.path.join(work_dir, 'cert.pem')
    key_path = os.path.join(work_dir, 'key.pem')

    base_cert = ['openssl', 'pkcs12', '-in', p12_path, '-out', cert_path,
                 '-clcerts', '-nokeys', '-passin', 'pass:']
    base_key = ['openssl', 'pkcs12', '-in', p12_path, '-out', key_path,
                '-nocerts', '-nodes', '-passin', 'pass:']

    # Try without -legacy first (LibreSSL on macOS, or modern p12s).
    if _try_run(base_cert) and _try_run(base_key):
        return cert_path, key_path

    # Fall back to -legacy (OpenSSL 3.x with old RC2-40 p12).
    _run(base_cert + ['-legacy'])
    _run(base_key + ['-legacy'])
    return cert_path, key_path


def _decode_profile(profile_path: str) -> bytes:
    """Return the plist bytes embedded in a CMS-wrapped .mobileprovision."""
    return subprocess.check_output([
        'openssl', 'smime', '-inform', 'der', '-verify', '-noverify',
        '-in', profile_path,
    ])


def _sign_profile(plist_path: str, output_path: str, cert_path: str, key_path: str) -> None:
    """CMS-sign a plist into a .mobileprovision file (DER).

    ``-noverify`` callers (Bazel + ``BuildConfiguration.py``) only need a
    well-formed CMS blob, so the signing identity does not matter.
    """
    _run([
        'openssl', 'cms', '-sign',
        '-signer', cert_path,
        '-inkey', key_path,
        '-in', plist_path,
        '-out', output_path,
        '-outform', 'der',
        '-binary',
        '-nodetach',
        '-md', 'sha256',
    ])


def rewrite_profiles(source_dir: str, output_dir: str, p12_path: str,
                     original_bundle_id: str, new_bundle_id: str) -> None:
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    with tempfile.TemporaryDirectory() as work_dir:
        cert_path, key_path = _extract_p12(p12_path, work_dir)

        for file_name in sorted(os.listdir(source_dir)):
            if not file_name.endswith('.mobileprovision'):
                continue
            source_path = os.path.join(source_dir, file_name)

            plist_data = _decode_profile(source_path)
            profile = plistlib.loads(plist_data)

            old_id = profile.get('Entitlements', {}).get('application-identifier', '')
            if original_bundle_id not in old_id:
                # Profile does not reference the original bundle id, copy as-is.
                shutil.copyfile(source_path, os.path.join(output_dir, file_name))
                print(f'  {file_name}: no rewrite needed ({old_id})')
                continue

            profile['Entitlements'] = _rewrite_entitlements(
                profile['Entitlements'], original_bundle_id, new_bundle_id,
            )
            # Also rewrite top-level fields that may embed the bundle id.
            if 'Name' in profile and isinstance(profile['Name'], str):
                profile['Name'] = _rewrite_string(profile['Name'], original_bundle_id, new_bundle_id)
            if 'AppIDName' in profile and isinstance(profile['AppIDName'], str):
                profile['AppIDName'] = _rewrite_string(
                    profile['AppIDName'], original_bundle_id, new_bundle_id,
                )

            new_plist = os.path.join(work_dir, file_name + '.plist')
            with open(new_plist, 'wb') as f:
                plistlib.dump(profile, f, fmt=plistlib.FMT_XML)

            output_path = os.path.join(output_dir, file_name)
            _sign_profile(new_plist, output_path, cert_path, key_path)

            new_id = profile['Entitlements']['application-identifier']
            print(f'  {file_name}: {old_id} -> {new_id}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True,
                        help='Source directory with .mobileprovision files.')
    parser.add_argument('--output', required=True,
                        help='Output directory for rewritten profiles.')
    parser.add_argument('--p12', required=True,
                        help='Path to fake self-signed p12 used for CMS signing.')
    parser.add_argument('--original-bundle-id', default='ph.telegra.Telegraph',
                        help='Bundle id baked into the source profiles.')
    parser.add_argument('--new-bundle-id', required=True,
                        help='Bundle id to use in the rewritten profiles.')
    args = parser.parse_args()

    print(f'Rewriting profiles: {args.original_bundle_id} -> {args.new_bundle_id}')
    rewrite_profiles(
        source_dir=args.source,
        output_dir=args.output,
        p12_path=args.p12,
        original_bundle_id=args.original_bundle_id,
        new_bundle_id=args.new_bundle_id,
    )


if __name__ == '__main__':
    main()
