# todo_rpc_client

## Client Boilerplate
Created a template that can be used as a starting point for any gRPC client.

### A Unary API
In terms of underlying protocol, the Unary API:
- Client
    - Send Header
    - Send Message
    - Half-Close
- Server
    - Send Message
    - Send Trailer

After implementing the `AddTask` endpoint on the server, a function called `addTask` has been created (within `main.go` of client).

Note that [todo_rpc_proto] (https://github.com/leofartes-2/todo_rpc_proto) is a **private** repository, so the `GOPRIVATE` environment variable needs to be used when pulling it into another go module, as shown below:

```
GOPRIVATE=github.com/leofartes-2/todo_rpc_proto go mod tidy
```

#### Dockerfile
The attached Dockerfile is used to build an image for the server, using the following commands:
```
$ eval $(ssh-agent)
$ ssh-add ~/.ssh/id_ed25519
$ docker buildx build --ssh default=$SSH_AUTH_SOCK --tag grpc_client --file todo_rpc_client/Dockerfile . 
```
