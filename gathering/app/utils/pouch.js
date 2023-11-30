import HttpPouch from 'pouchdb-adapter-http';
import indexeddb from 'pouchdb-adapter-indexeddb';
import MemoryAdapter from 'pouchdb-adapter-memory';
import PouchDB from 'pouchdb-core';
import PouchDBDebug from 'pouchdb-debug';
import PouchDBFind from 'pouchdb-find';
import mapreduce from 'pouchdb-mapreduce';
import replication from 'pouchdb-replication';
import PouchDBRelational from 'relational-pouch';

window.process = window.process || {};
window.global = window;

PouchDB.plugin(PouchDBDebug)
  .plugin(PouchDBFind)
  .plugin(PouchDBRelational)
  .plugin(indexeddb)
  .plugin(MemoryAdapter)
  .plugin(HttpPouch)
  .plugin(mapreduce)
  .plugin(replication);

export default PouchDB;
