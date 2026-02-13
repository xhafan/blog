#!/bin/sh
docker build -t xhafanblog .
docker run -it --rm -p 80:80 xhafanblog
# access it on http://172.19.208.1/blog/