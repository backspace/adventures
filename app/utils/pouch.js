
import PouchDB from 'ember-pouch/pouchdb';
import MemoryAdapter from 'pouchdb-adapter-memory';
import PouchDBDebug from 'pouchdb-debug';

window.process = window.process || {};
window.global = window;

PouchDB
  .plugin(MemoryAdapter)
  .plugin(PouchDBDebug)
  ;

export default PouchDB;
