# Affirmate

A place for things ❤️‍🔥

## What is it

An encrypted chat app, inspired by Signal's implementation of encryption, but much less securely implemented. Don't use this for anything serious unless you have experience with encryption and have a thorough system for vetting your stuff.

But the system is all built purely in Swift. There's a Vapor server that stands up a mongo database, and a good start on a universal Swift chat app that syncs encrypted chats to other devices through CloudKit.

Real-time chat features (including typing indicators and incoming messages when the app is open) are managed through a custom websocket connection.

All in all, it was a big lift, and a fun project to work on!

## Set Up Server Development Environment

In order to build and run the server locally you will need to pass in a variety of Arguments and Environment Variables. The Environment Variables are also reccomended on a production server as well, but this repo isn't there yet.

### You will need

#### Arguments Passed on Launch

* `serve --hostname 0.0.0.0 --port 8080`

#### Environment Variables (Optional)

* `APNS_TEAM_ID`: `<Your Team ID>`
* `APNS_KEY`: `<Your .pem Private Key (downloaded from developer.apple.com, and configured with APNS permissions)`
* `APNS_KEY_ID`: `<Your .pem Key ID (found on the page you downloaded your private key from)>`

See the following screenshot for an example of all the required keys and arguments:

<img width="440" alt="Required Server Arguments and Environment Variables" src="https://user-images.githubusercontent.com/5713359/186994861-bea4c1af-7d36-435f-be0f-1bdc808a0a88.png">

## Start the database

Navigate to the `Developer` directory and build the docker containers with `docker-compose`:

```shell
cd Affirmate/AffirmateServer
docker-compose build db
docker-compose up db
```

Before the database can work the server needs to run a migration, which creates all the tables in the database. Run the following command from `Affirmate/AffirmateServer` to start the migration:

```shell
vapor run migrate
```

## Start the server in Xcode

Before the app will connect to the database, the server needs to be running.

Select the target `Run` and click the play button to build and run the server on your Mac.

It will be running at `http://0.0.0.0:8080`.

You should see `[ NOTICE ] Server starting on http://0.0.0.0:8080 (Vapor/HTTPServer.swift:296)` towards the bottom of the Xcode console.

## Run one of the clients

Now that the database and the server are up and running you can build and run the iOS, watchOS, or macOS apps and they should connect to the same database/server instance running on your Mac.

## Account deletion

Authenticated users can remove their account by sending an HTTP `DELETE` request to `/me`. The server responds with `204 No Content` once the account has been deleted, and all of the user's session tokens, chat participation, invitations, and public keys are removed. The clients now treat this empty success response as a completed deletion.

## Authentication Architecture Flow

<img width="250" alt="Authentication Architecture Flow" src="https://user-images.githubusercontent.com/5713359/187051690-515e22ae-0728-4b4f-81cb-4771d5100b5d.png">
