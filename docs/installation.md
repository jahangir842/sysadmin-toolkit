# Installation and removal

Review a tagged release and its checksums before installing. From an unpacked,
verified source tree:

```sh
sudo install -d -o root -g root -m 0755 /usr/local/lib/sysadmin-toolkit/{bin,lib}
sudo install -o root -g root -m 0755 bin/* /usr/local/lib/sysadmin-toolkit/bin/
sudo install -o root -g root -m 0644 lib/*.sh /usr/local/lib/sysadmin-toolkit/lib/
sudo ln -s /usr/local/lib/sysadmin-toolkit/bin/host-security-audit /usr/local/sbin/host-security-audit
```

The command resolves symlinks before locating its adjacent `lib` directory, so
the `/usr/local/sbin` link remains relocatable as a unit with the installation.

Run locally with `sudo host-security-audit`. Without root, checks that need
privilege are reported `UNKNOWN`; the tool does not silently infer results.

Remove only installed toolkit paths after verifying them:

```sh
sudo unlink /usr/local/sbin/host-security-audit
sudo rm -r /usr/local/lib/sysadmin-toolkit
```

No automatic production deployment or unattended remote execution is provided.
