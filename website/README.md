# CNDF 2023 sample website

## Setup

```shell
# in this directory
$ bundle install
$ npm install
```

## Build

```shell
$ bundle exec middleman build
```

## Deploy

### Amazon S3 bucket

Prerequirement: AWS CLI

```shell
# in this directory
$ bundle exec middleman build
$ aws s3 sync build/ s3://your-bucket-name [--dryrun]
```

### Firebase Hosting

```shell
# in this directory
$ bundle exec middleman build
$ npx firebase login
$ npx firebase deploy
```

## Licenses
Images in the `source/images/` directory are from Twemoji. Licensed under CC-BY 4.0.

Copyright 2020 Twitter, Inc
<https://creativecommons.org/licenses/by/4.0/>
