rmtrash
=======

rmtrash is a small utility that will move the file to OS X's Trash rather than
obliterating the file (as rm does).

Compatibility
-------------

Mac OS X 10.0 through Mac OS X 10.10
(only tested on 10.10 so far)

Install
-------
Open a terminal and type
```
cd /path/to/clone/to/
git clone https://github.com/beatjunky99/rmtrash-for-Mac-OS-X.git
cd rmtrash
```
- OS X 10.0+: `cd rmtrash && make`
- OS X 10.4+: `sudo xcodebuild install -project rmtrash\ \(no\ arc\).xcodeproj/`
- OS X 10.6+: `sudo xcodebuild install -project rmtrash.xcodeproj/`

License
-------

All credit to: [nightproductions.net][1]

[1]: http://www.nightproductions.net/cli.htm
