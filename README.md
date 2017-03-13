# Diplomacy

Diplomacy is a board game. This is the Diplomacy board game rule set I wrote in
2003/2004 at UNSW because I liked playing board games and coding Ruby and had a
lot of spare time.

The code is pretty awful because I had only just learned Ruby so I used eval and
monkey patched things and mutated state everywhere.

I'd like to hammer it into shape which involves the following steps:

- [x] Put it on GitHub so I'm too embarrassed to leave it there in its current state
- [x] Replace all the monkey patching with non monkey based code
- [ ] Rubocop it to within an inch of its life
- [ ] Set up unit test coverage reporting
- [ ] Add more unit tests as necessary for coverage and sanity
- [ ] Probably retire the FXRuby GUI I wrote but leave it there for now
- [ ] Refactor lots of if statements, mostly by limiting possible values for data
  - [x] Switch the initializers to use keyword arguments
  - [ ] Use dry-initializer to ensure objects get initialized sanely
  - [ ] Pull REXML code out of Map and rewrite it
- [ ] Dependency-inject stuff (e.g. loggers to avoid `log` and `ailog` calls
      everywhere)
- [ ] Turn it into a gem and publish it
- [ ] Profile it and see if there are any log hanging fruit
- [ ] Use it in a Rails app and put it on Heroku so people can play vanilla
      Diplomacy together
- [ ] If I don't hate it by then, write a version in Haskell and a version in
      Elixir for comparison

