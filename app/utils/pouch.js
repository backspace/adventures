import PouchDB from "pouchdb-core";
import PouchDBDebug from "pouchdb-debug";
import PouchDBFind from "pouchdb-find";
import PouchDBRelational from "relational-pouch";
import indexeddb from "pouchdb-adapter-indexeddb";
import HttpPouch from "pouchdb-adapter-http";
import mapreduce from "pouchdb-mapreduce";
import replication from "pouchdb-replication";

window.process = window.process || {};
window.global = window;

PouchDB.plugin(PouchDBDebug)
  .plugin(PouchDBFind)
  .plugin(PouchDBRelational)
  .plugin(indexeddb)
  .plugin(HttpPouch)
  .plugin(mapreduce)
  .plugin(replication);

export default PouchDB;
