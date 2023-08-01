# Containerfiles

## What's this directory

This directory contains source `Container`s of nginx and h2o container image.

The configuration of container images, such as nginx.conf, differs for each architecture.

`Containerfile` which contains only common parts is located in this directory.

## How to build

See also [`Rakefile`](/Rakefile) in repository root.

### nginx

```shell
# on repository root
$ docker build --tag cndf2023-nginx-base:latest  --file containerfiles/nginx/Containerfile .

# or use rake (also on repository root)
$ rake build:base:nginx
```

### h2o

```shell
# on repository root
$ docker build --tag cndf2023-h2o-base:latest  --file containerfiles/h2o/Containerfile .

# or use rake (also on repository root)
$ rake build:base:h2o
```
