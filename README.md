# Install master version

```sh
wget -O - https://github.com/NitorCreations/aws-utils/archive/master.tar.gz | sudo tar -xzf - --strip 1 -C /
```

# lpssh

This is a utility that lets you keep ssh private keys in lastpass and never on your
own machine.

## Prerequisites

You need to have the tools installed as above

## Usage:

 First you need to login to LastPass:
 ```
 lpass login <your@user.name>
 ```
 The login supports most 2nd factor tools you may have configured.

You then need to have a mapping note in lastpass that tells the tool which key to
use for which username/host combination. Here is an example:
```
ubuntu@bob.nitor.zone:nitor-infra.rsa
centos@inside.nitor.zone:nitor-infra.rsa
centos@hours.nitor.zone:nitor-infra.rsa
```
There is one mapping per line and the format is ```[user]@[host]:[keyname]```

Then the tools supports tab completion to fill in the arguments.

```
usage: lpssh [-k keyname] <user>@<host>
```

The ```-k``` parameter enables specifying a key name in LastPass explicitly
bypassing the mapping note.

The tool will then find the correct key, start a private ssh-agent for the session
and adds the key via stdin (the key is never stored on your computer). After the
ssh session ends, the script will kill the ssh-agent used for the authentication.
