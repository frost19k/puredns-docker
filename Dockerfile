# syntax=docker/dockerfile:1.3-labs

FROM golang:1.17-alpine AS puredns
ENV GO111MODULE=on
RUN go install github.com/d3mondev/puredns/v2@latest

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

FROM alpine:3.14 AS massdns
RUN <<eot
apk add --update --no-cache build-base git ldns-dev
git clone --branch=master --depth=1 https://github.com/blechschmidt/massdns.git
cd /massdns
make
eot

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

FROM alpine:3.14 AS final
LABEL maintainer="Maaz Basar <maazbasar@icloud.com>"

COPY --from=massdns /massdns/bin/massdns /usr/local/bin/
COPY --from=puredns /go/bin/puredns /usr/local/bin/

WORKDIR /puredns
COPY LICENSE .
RUN <<eot
apk add --update --no-cache ldns
wget https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt
eot

ENTRYPOINT [ "puredns" ]
CMD [ "--help" ]
