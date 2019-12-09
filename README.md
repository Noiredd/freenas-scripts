## freenas-scripts

My collection of scripts to automate my [FreeNAS](http://www.freenas.org) server.

Each folder is a separate subsystem (jail) - refer to the individual readmes for help.

I haven't built *all* of this code myself - parts have been adapted or straight up copied from various sources online (I will add credit where necessary).

#### Contents:

* [OpenVPN + Transmission](/openvpn) (with port forwarding and downtime detection)
* [AutoBackup](/autobackup) (have your server detect you've just connected an external HDD and automatically backup to it with encryption)
* [SMARTmail](/smartmail) (periodically receive e-mails with results of the last SMART health check)
* torrent management (maybe coming sometime)

#### Disclaimer
I am not a linux expert so I will not provide support for any of those scripts.
Maybe it's better to consider them as reference for your own solutions
(or maybe after reading them you will decide that they're good enough for you).
I'm using them on my setup and nothing broke yet, but YMMV.
