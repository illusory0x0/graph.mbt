///|
priv struct Node[A] {
  mut _value : A
  mut _state : State
  mut _id : Int
  _init : () -> A
  _out_edges : Array[&VNode]
} derive(Show)

///|
priv enum State {
  Stale
  Fresh
} derive(Eq, Compare, Show, Hash)

///|
priv trait VNode {
  update(Self) -> Unit
  set_state(Self, State) -> Unit
  state(Self) -> State
  out_edges(Self) -> Array[&VNode]
  id(Self) -> Int
  output_vnode(Self, &Logger) -> Unit
}

///|
impl Show for &VNode with output(self, logger) {
  self.output_vnode(logger)
}

///|
impl[A : Show] VNode for Node[A] with output_vnode(self, logger) {
  self.output(logger)
}

///|
impl[A : Show] VNode for Node[A] with update(self) {
  self._value = (self._init)()
  self._state = Fresh
}

///|
impl[A : Show] VNode for Node[A] with set_state(self, state) {
  self._state = state
}

///|
impl[A : Show] VNode for Node[A] with state(self) {
  self._state
}

///|
impl[A : Show] VNode for Node[A] with out_edges(self) {
  self._out_edges
}

///|
impl[A : Show] VNode for Node[A] with id(self) {
  self._id
}

///|
impl[A] Eq for Node[A] with op_equal(self, other) {
  self._id == other._id
}

///|
impl Eq for &VNode with op_equal(self, other) {
  self.id() == other.id()
}

///|
impl[A] Compare for Node[A] with compare(self, other) {
  self._id.compare(other._id)
}

///|
impl Compare for &VNode with compare(self, other) {
  self.id().compare(other.id())
}

///|
let id_counter : Ref[Int] = Ref::new(0)

///|
fn Node::from_fun[A](init : () -> A) -> Node[A] {
  id_counter.update(fn { x => x + 1 })
  {
    _value: init(),
    _init: init,
    _id: id_counter.val,
    _out_edges: [],
    _state: Fresh,
  }
}

///|
fn Node::from_val[A](value : A) -> Node[A] {
  Node::from_fun(fn() { value })
}

///|
fn Node::depend_on[A : Show](self : Node[A], other : &VNode) -> Unit {
  other.out_edges().push(self)
}

///|
fn Node::map[A : Show, B : Show](self : Node[A], f : (A) -> B) -> Node[B] {
  let res = Node::from_fun(fn() { f(self.get()) })
  res.depend_on(self)
  res
}

///|
fn &VNode::dfs(self : &VNode) -> Unit {
  match self.state() {
    Stale => ()
    Fresh => {
      self.set_state(Stale)
      for out_edge in self.out_edges() {
        &VNode::dfs(out_edge)
      }
    }
  }
}

///|
fn Node::get[A : Show](self : Node[A]) -> A {
  match self._state {
    Stale => {
      self.update()
      self._value
    }
    Fresh => self._value
  }
}

///|
fn Node::set[A : Show](self : Node[A], value : A) -> Unit {
  self._value = value
  for out_edge in self.out_edges() {
    &VNode::dfs(out_edge)
  }
}

///|
fn Node::modify[A : Show](self : Node[A], f : (A) -> A) -> Unit {
  self.set(f(self.get()))
}

///|
fn map_log[A : Show, B : Show](
  self : Node[A],
  t : @test.T,
  f : (A) -> B
) -> Node[B] {
  self.map(fn(x) {
    let v = f(x)
    t.writeln(v)
    v
  })
}

///|
test (t : @test.T) {
  let a = Node::from_val(1)
  t.writeln("EVAL BEGIN")
  let b0 = a.map_log(t, fn { x => x * 2 })
  let b1 = a.map_log(t, fn { x => x * 3 })
  let c = Node::from_fun(fn() {
    let v = b0.get() + b1.get()
    t.writeln(v)
    v
  })
  t.writeln("EVAL END\n")
  c.depend_on(b0)
  c.depend_on(b1)
  inspect!(c.get(), content="5")
  a.modify(fn { x => x + 5 })
  inspect!(a.get(), content="6")
  inspect!(c.state(), content="Stale")
  t.writeln("EVAL BEGIN")
  inspect!(c.get(), content="30")
  t.writeln("EVAL END\n")
  inspect!(c.state(), content="Fresh")
  t.snapshot!(filename="test1.txt")
}
