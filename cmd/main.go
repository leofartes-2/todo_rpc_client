package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/types/known/timestamppb"

	todorpcproto "github.com/leofartes-2/todo_rpc_proto"
)

func addTask(
	client todorpcproto.TodoServiceClient,
	description string,
	dueDate time.Time,
) uint64 {
	req := &todorpcproto.AddTaskRequest{
		Description: description,
		DueDate:     timestamppb.New(dueDate),
	}
	res, err := client.AddTask(context.Background(), req)
	if err != nil {
		panic(err)
	}
	fmt.Printf("added task: %d\n", res.Id)
	return res.Id
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		log.Fatalln("usage: client [IP_ADDR]")
	}

	addr := args[0]
	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	}
	conn, err := grpc.NewClient(addr, opts...)
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer func(conn *grpc.ClientConn) {
		if err := conn.Close(); err != nil {
			log.Fatalf("unexpected error: %v", err)
		}
	}(conn)

	c := todorpcproto.NewTodoServiceClient(conn)

	fmt.Println("---------- ADD ----------")
	dueDate := time.Now().Add(1 * time.Minute)
	addTask(c, "This is task one", dueDate)
}
