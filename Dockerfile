FROM golang:1.19-alpine3.16 AS builder

RUN apk add --update --no-cache ca-certificates make git curl alpine-sdk

RUN mkdir -p /usr/local/src/demo
WORKDIR /usr/local/src/demo

COPY . .

RUN mkdir -p build
RUN go build -o /usr/local/bin/demo


FROM alpine:3.16.2

RUN apk add --update --no-cache ca-certificates tzdata bash curl

SHELL ["/bin/bash", "-c"]

COPY --from=builder /usr/local/bin/demo /usr/local/bin/

EXPOSE 8080

CMD ["demo"]
