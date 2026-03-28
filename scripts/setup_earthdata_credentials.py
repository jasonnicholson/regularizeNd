#!/usr/bin/env python3
"""
Store a NASA Earthdata Bearer token in the GNOME Keyring.

The keyring is unlocked automatically by your desktop login session key.
Nothing is written to a plain-text file.  Your Earthdata password is never
asked for or stored.

Usage (one-time setup):
    python scripts/setup_earthdata_credentials.py

How to get a token
------------------
  1. Go to  https://urs.earthdata.nasa.gov
  2. Sign in, then click "Generate Token" in the top navigation.
  3. Click "Generate Token", then "Show Token" and copy the value.
  4. Paste it when this script prompts for it.

The token is valid for 60 days.  Re-run this script to refresh it.
"""

import getpass
import sys
import keyring

SERVICE = "nasa-earthdata"


def main() -> None:
    print("=== NASA Earthdata token setup ===")
    print("Paste your Earthdata Bearer token below (input is hidden).")
    print("Get one at: https://urs.earthdata.nasa.gov  → Generate Token\n")

    token = getpass.getpass("Bearer token (not echoed): ").strip()
    if not token:
        sys.exit("Cancelled — no token entered.")

    username = input("Earthdata username (for earthaccess): ").strip()
    if not username:
        sys.exit("Cancelled — no username entered.")

    keyring.set_password(SERVICE, "token", token)
    keyring.set_password(SERVICE, "username", username)

    backend = type(keyring.get_keyring()).__name__
    print(f"\nStored in system keyring ({backend}).")
    print("Token and username are encrypted by your login-session key.")
    print("\nSetup complete.  Run  python scripts/download_icesat2.py  to fetch data.")


if __name__ == "__main__":
    main()
