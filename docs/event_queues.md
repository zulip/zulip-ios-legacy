# Event Queue overview

We have 2 event queues that are connected to our Zulip servers.

## Resuming

Basically there are a couple of things that can happen on resume:

* Your message event queue is still valid (which means you were active in the last 10min)
  -> Then we simply drain the queue and show the new messages

* Your message event queue is invalid (garbage collected on server)
   -> We basically reload around your pointer, calling initialPopulate

* Your metadata queue is invalid (idle for >1week)
   -> We do a clean reset and load from an empty database

If your connectivity really sucks… a lot of things might break. E.g. the initial populate might not succeed, or loading the event queue might fail, etc. In all those cases we’ll show the “Error screen” once enough failures have been encountered.

