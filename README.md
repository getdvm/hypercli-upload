upload hyper cli to s3
===================================

#install dependency

## install awscli
```
//linux
$ pip install awscli

//macosx
$ brew install awscli
```

## config awscli
```
$ aws --profile hyper configure
```

#prepare hyper cli binary
```
$ tree ready
ready
├── arm
│   ├── checksum
│   └── hyper-arm
├── linux
│   ├── checksum
│   └── hyper-linux
└── mac
    ├── checksum
    └── hyper-mac
```

#start upload
```
$ ./util.sh upload linux
$ ./util.sh upload mac
$ ./util.sh upload arm
```

# list s3
```
$ ./util.sh list
or
$ ./util.sh list 20160426
```
