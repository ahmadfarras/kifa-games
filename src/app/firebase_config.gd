class_name FirebaseConfig
extends RefCounted

## The Firebase project the game talks to. The Web API key only says which project a request is for;
## it is public by design (it ships inside every build) and grants nothing by itself: what an account
## may do is decided on the server by firestore.rules. Real secrets (service accounts) never go here.

const PROJECT_ID := "kifa-games"
const API_KEY := "AIzaSyBN6CLoXFsZ_seMm2MzPOZ9s0yeZ7BBLuE"
