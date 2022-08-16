#if compiler(>=5.7)
  /// A protocol that describes how to evolve the current state of an application to the next state,
  /// given an action, and describes what ``Effect``s should be executed later by the store, if any.
  ///
  /// There are two ways to define a reducer:
  ///
  ///   1. You can either implement the ``reduce(into:action:)-4nzr2`` method, which is given direct
  ///      mutable access to application ``State`` whenever an ``Action`` is fed into the system,
  ///      and returns an ``Effect`` that can communicate with the outside world and feed additional
  ///      ``Action``s back into the system.
  ///
  ///   2. Or you can implement the ``body-swift.property-5mc0o`` property, which combines one or
  ///      more reducers together.
  ///
  /// At most one of these requirements should be implemented. If a conformance implements both
  /// requirements, only ``reduce(into:action:)-4nzr2`` will be called by the ``Store``. If your
  /// reducer assembles a body from other reducers _and_ has additional business logic it needs to
  /// layer onto the feature, introduce this logic into the body instead, either with ``Reduce``:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Reduce { state, action in
  ///     // extra logic
  ///   }
  ///   Activity()
  ///   Profile()
  ///   Settings()
  /// }
  /// ```
  ///
  /// …or with a separate, dedicated conformance:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<State, Action> {
  ///   Core()
  ///   Activity()
  ///   Profile()
  ///   Settings()
  /// }
  /// struct Core: ReducerProtocol<State, Action> {
  ///   // extra logic
  /// }
  /// ```
  ///
  /// If you are implementing a custom reducer operator that transforms an existing reducer,
  /// _always_ invoke the ``reduce(into:action:)-4nzr2`` method, never the
  /// ``body-swift.property-5mc0o``. For example, this operator that logs all actions sent to the
  /// reducer:
  ///
  /// ```swift
  /// extension ReducerProtocol {
  ///   func logActions() -> some ReducerProtocol<State, Action> {
  ///     Reduce { state, action in
  ///       print("Received action: \(action)")
  ///       return self.reduce(into: &state, action: action)
  ///     }
  ///   }
  /// }
  /// ```
  public protocol ReducerProtocol<State, Action> {
    /// A type that holds the current state of the application.
    associatedtype State

    /// A type that holds all possible actions that cause the ``State`` of the application to change
    /// and/or kick off a side ``Effect`` that can communicate with the outside world.
    associatedtype Action

    /// A type representing the body of this reducer.
    ///
    /// When you create a custom reducer by implementing the ``body-swift.property-5mc0o``, Swift
    /// infers this type from the value returned.
    ///
    /// If you create a custom reducer by implementing the ``reduce(into:action:)-4nzr2``, Swift
    /// infers this type to be `Never`.
    associatedtype Body

    /// Evolves the current state of an application to the next state.
    ///
    /// Implement this requirement for "primitive" reducers, or reducers that work on leaf node
    /// features. To define a reducer by combining the logic of other reducers together, implement
    /// the ``body-swift.property-5mc0o`` requirement instead.
    ///
    /// - Parameters:
    ///   - state: The current state of the application.
    ///   - action: An action that can cause the state of the application to change, and/or kick off
    ///     a side effect that can communicate with the outside world.
    /// - Returns: An effect that can communicate with the outside world and feed actions back into
    ///   the system.
    func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

    /// The content and behavior of a reducer that is composed from other reducers.
    ///
    /// Implement this requirement when you want to incorporate the behavior of other reducers
    /// together.
    ///
    /// Do not invoke this property directly.
    ///
    /// > Important: if your reducer implements the ``reduce(into:action:)-4nzr2`` method, it will
    /// > take precedence over this property, and only ``reduce(into:action:)-4nzr2`` will be called
    /// > by the ``Store``. If your reducer assembles a body from other reducers and has additional
    /// > business logic it needs to layer into the system, introduce this logic into the body
    /// > instead, either with ``Reduce``, or with a separate, dedicated conformance.
    @ReducerBuilder<State, Action>
    var body: Body { get }
  }

  /// A convenience type alias for referring to a reducer of the given reducer's domain.
  ///
  /// Instead of specifying two generics:
  ///
  /// ```swift
  /// var body: some ReducerProtocol<Feature.State, Feature.Action> {
  ///   // ...
  /// }
  /// ```
  ///
  /// You can specify a single generic:
  ///
  /// ```swift
  /// var body: some ReducerProtocolOf<Feature> {
  ///   // ...
  /// }
  /// ```
  public typealias ReducerProtocolOf<R: ReducerProtocol> = ReducerProtocol<R.State, R.Action>
#else
  public protocol ReducerProtocol {
    associatedtype State

    associatedtype Action

    associatedtype Body

    func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

    @ReducerBuilder<State, Action>
    var body: Body { get }
  }
#endif

extension ReducerProtocol where Body == Never {
  /// A non-existent body.
  ///
  /// > Warning: Do not invoke this property directly. It will trigger a fatal error at runtime.
  @_transparent
  public var body: Body {
    // TODO: Should this be a `runtimeWarning` and return `Void` instead?
    fatalError(
      """
      '\(Self.self)' has no body. …

      Do not access a reducer's 'body' property directly, as it may not exist. To run a reducer, \
      call 'Reducer.reduce(into:action:)', instead.
      """
    )
  }
}

extension ReducerProtocol where Body: ReducerProtocol, Body.State == State, Body.Action == Action {
  /// Invokes the ``Body-40qdd``'s implementation of ``reduce(into:action:)-4nzr2``.
  @inlinable
  public func reduce(
    into state: inout Body.State, action: Body.Action
  ) -> Effect<Body.Action, Never> {
    self.body.reduce(into: &state, action: action)
  }
}

// TODO: explore ReducerModifier
//extension OVerrideDemoDependencies: reducerModifier {
//  @Dep(\.isDemo)
//
//  func body(base: R) -> some {
//    if isDemo {
//      base.dep(...)
//    } else {
//      base
//    }
//  }
//}
//
//extension ReducerProtocol {
//  func overrideDemoDeps(isDemo: Bool) {
//    if isDemo {
//      self.dep(...)
//    } else {
//      self
//    }
//  }
//}
//
//func testDependency_EffectOfEffect() async {
//  struct Feature: ReducerProtocol {
//    var body {
//      CombineReducers {
//        ...
//      }
//      .modifier(OverrideDemoDependencies())
//    }
