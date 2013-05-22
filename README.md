## feed2imap.rb

Simple script to manage your rss feeds in imap folders.

### Config directory:
Configuration files are stored under $HOME/.config/feed2imap.rb directory.

### Imap settings:
$HOME/.config/feed2imap.rb/imap.yml - imap settings:
```
host: imap.host.com
port: 993
username: email@gmail.com
password: myawesomepass
to: to@email.com
from: from@email.com
```

### Usage:
* `feed2imap.rb add <folder-name> <feed-url>` - add feed to feeds file.
* `feed2imap.rb pull` - pull feeds.
