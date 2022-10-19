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

<img width="440" alt="Required Server Arguments and Environment Variables" src="https://user-images.githubusercontent.com/5713359/186994861-bea4c1af-7d36-435f-be0f-1bdc808a0a88.png">

## Authentication Architecture Flow
<img width="100" alt="Authentication Architecture Flow" src="https://user-images.githubusercontent.com/5713359/187051690-515e22ae-0728-4b4f-81cb-4771d5100b5d.png">

## (Simple) Chat Message Encryption - Alice and Bob

1. Alice creates an account with the username `alice`.
    * The server creates a `User` record for Alice with a publicly indexed `username` field `alice`.
    * Upon recieving a response, Alice's device logs her in with her new credentials.
2. Bob creates an account with the public username `bob`.
    * The server creates a `User` record for Bob with a publicly indexed `username` field `bob`.
    * Upon recieving a response, Bob's device logs her in with his new credentials.
3. Alice composes a new chat locally on her device.
    * Alice's device generates a key pair using the on-device secure enclave via Apple's `CryptoKit`, and stores it into her keychain, referencing the chat.
4. Alice attaches Bob's `User` record to the chat by searching for Bob's public username `bob` (via `GET /users/find`).
5. Alice sends a reference to Bob's `User` and her new public key to `POST /chats`.
    1. The server creates a `Chat` object in the database.
    2. The server creates a `ChatParticipant` object for Alice in the database containing a reference to the `Chat` record, and a reference to Alice's `User` record.
    3. The server creates a `ChatPublicKey` object in the database, containing the actual public key data, and referencing Alice's `ChatParticipant` record.
    4. The server creates a `ChatInvitation` object in the database, referencing the `Chat` record, Alice's `User` record, and Bob's `User` record.
6. Bob recieves the newly created `ChatInvitation` with Alice's public key on his device and has the option to accept or decline.
7. Bob accepts the invitation.
    1. Bob's device generates a key pair using the on-device secure enclave via Apple's `CryptoKit`, and stores it into his keychain, referencing the chat.
    2. Bob's device sends a `join` request to the server containing his public key.
    3. The server creates a `ChatParticipant` object for Bob in the database, containing a reference to the `Chat` record, and a reference to Bob's `User` record.
    4. The server creates a `ChatPublicKey` object in the database, containing the actual public key data, and referencing Bob's `ChatParticipant` record.
8. Upon successfully joining the chat, Bob recieves the `Chat` object from the API containing Alice's `ChatParticipant` with her public key. 
    * Bob's device opens a WebSocket connection to the server for updates to the `Chat` object (new messages, etc.).
9. Alice recieves Bob's new `ChatParticipant` object (with the referenced public key) and a `Chat` appears on screen. 
    * Alice's device opens a WebSocket connection to the server for updates to the `Chat` object (new messages, etc.).
10. Alice sends Bob a message containing text over the WebSocket connection.
    1. Alice's device uses both Alice's and Bob's public keys to encrypt and sign the outgoing message.
    2. Alice's device sends a message through the open WebSocket connection.
    3. Alice recieves her new message through the open WebSocket connection, then uses's Bob's public key with her private key to unwrap the encrypted message.
    4. The message is displayed on screen.
11. Bob recieves a new encrypted message from Alice.
    1. Bob's device uses Alice's public key with his private key to unwrap the encrypted message.
    2. The unencrypted message is displayed on screen.
12. Bob writes a reply and sends it to the chat.
    1. Bob's device uses both Bob and Alice's keys to encrypt and sign the outgoing message.
    2. Bob's device sends a message through the open WebSocket connection.
    3. Bob recieves his new message through the open WebSocket connection, then uses Alice's public key with his private key to unwrap the encrypted message.
    2. The unencrypted message is displayed on screen.
13. Alice recieves a new encrypted message from Bob.
    1. Bob's device uses Alice's public key with his private key to unwrap the encrypted message.
    2. The unencrypted message is displayed on screen.
