
import PouchDB from 'ember-pouch/pouchdb';
import MemoryAdapter from 'pouchdb-adapter-memory';

window.process = window.process || {};
window.global = window;

PouchDB
  .plugin(MemoryAdapter)
  ;

export default PouchDB;
