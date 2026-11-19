FROM golang:1.24.0-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /service ./main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /service /service
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/service"]

