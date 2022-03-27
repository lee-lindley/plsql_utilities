# as_zip
A package for reading and writing ZIP archives as BLOBs published by Anton Scheffer
[compress-gzip-and-zlib](https://technology.amis.nl/it/utl_compress-gzip-and-zlib/).

Other than splitting into .pks and .pkb files, the only change I made was declaring
the package to use invoker rights (AUTHID CURRENT_USER). The reason is that it can write
a file to a directory and that priviledge should depend on the caller.

Somewhere along the way I picked up a version that added an optional Date argument to *add1file*.
It is a slight mismatch from the above link. Seems useful though. If you already have as_zip
installed without it, you might choose to remove the optional date argument from methods in *app_zip*.

