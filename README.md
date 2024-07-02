# Simple Contact Book

## Running the Project

This project uses Docker Compose to manage the application containers. To run the project, you will need to have Docker and Docker Compose installed on your system.

## Starting the Containers

To start the containers, navigate to the project's root directory in your terminal and run the following command:

```shell
git clone --recurse-submodules https://github.com/lehcode/contact-book-root.git
docker-compose up -d --build ui-vue
```

This command will start the containers in the background.

## Accessing the Application

After starting the containers, you can access the application by visiting http://localhost in your web browser.

## Stopping the Containers

To stop the containers, run the following command in the project's root directory:

```shell
docker-compose down
```

This command will stop and remove the containers.

## Other Commands
You can run other commands using Docker Compose. For example, to rebuild the containers, you can run:

```shell
docker-compose up --build -d
```