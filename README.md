# Affirmate
A chosen family ❤️‍🔥

## Set Up Server Development Environment
In order to build and run the server locally you will need to pass in a variety of Arguments and Environment Variables. The Environment Variables are also reccomended on a production server as well, but this repo isn't there yet.

### You will need:
#### Arguments Passed on Launch:
 * `serve --hostname 0.0.0.0 --port 8080`
#### Environment Variables
 * `APNS_TEAM_ID`: `<Your Team ID>`
 * `APNS_KEY`: `<Your .pem Private Key (downloaded from developer.apple.com, and configured with APNS permissions)`
 * `APNS_KEY_ID`: `<Your .pem Key ID (found on the page you downloaded your private key from)>`

See the following screenshot for an example of all the required keys and arguments:

<img width="440" alt="Screenshot 2022-08-26 at 2 39 58 PM" src="https://user-images.githubusercontent.com/5713359/186994861-bea4c1af-7d36-435f-be0f-1bdc808a0a88.png">
