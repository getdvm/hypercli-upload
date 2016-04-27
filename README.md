upload hyper cli to s3
===================================

- set acl: public-read
- chmod +x hyper


# install awscli

```
//linux
$ pip install awscli

//macosx
$ brew install awscli


//config
$ aws --profile hyper configure
```

# prepare hyper cli binary
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

# compress
```
$ ./util.sh compress linux
$ ./util.sh compress mac
$ ./util.sh compress arm
```

# upload

1. upload/{YYYYMMDD}/{linux,arm,mac}
2.  s3://mirror-hyper-install/hyperserve-cli-bak/{YYYYMMDD}/{linux,arm,mac}  
3. s3://mirror-hyper-install/  
4. s3://hyper-install/  

> upload progress

- s3 sync local dir 1 to 2
- s3 cp file from 2 to 3
- s3 cp file from 2 to 4

```
$ ./util.sh upload linux
$ ./util.sh upload mac
$ ./util.sh upload arm
```

# list

## list local file in upload dir
```
$ ./util.sh list local
```

## list remote file on s3
```
$ ./util.sh list remote
```
