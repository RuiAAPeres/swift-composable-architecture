import ComposableArchitecture
import GRDB
@preconcurrency import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

@Reducer
struct Todos {
  @ObservableState
  struct State: Equatable {
    var editMode: EditMode = .inactive
    var filter: Filter = .all
    @Shared(.query(Todo.all().order(Column("isComplete").asc))) var todos: IdentifiedArray = []
  }

  enum Action: BindableAction, Sendable {
    case addTodoButtonTapped
    case binding(BindingAction<State>)
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case move(IndexSet, Int)
    case onAppear
    case todos(IdentifiedActionOf<TodoFeature>)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  private enum CancelID { case todoCompletion }

  @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue

  var body: some Reducer<State, Action> {
    CombineReducers {
      BindingReducer()
      Reduce { state, action in
        switch action {
        case .addTodoButtonTapped:
          return .run { _ in
            try defaultDatabaseQueue.inDatabase { db in
              try Todo().insert(db)
            }
          }
          
        case .binding:
          return .none
          
        case .clearCompletedButtonTapped:
          let ids = state.todos.filter(\.isComplete).ids
          return .run { _ in
            try defaultDatabaseQueue.inDatabase { db in
              _ = try Todo.deleteAll(db, ids: ids)
            }
          }

        case let .delete(indexSet):
          let ids = indexSet.map { state.todos[$0].id }
          return .run { _ in
            try defaultDatabaseQueue.inDatabase { db in
              _ = try Todo.deleteAll(db, ids: ids)
            }
          }
          
        case var .move(source, destination):
          //        if state.filter == .completed {
          //          let filteredTodoIDs = state.filteredTodoIDs
          //          source = IndexSet(
          //            source
          //              .map { filteredTodoIDs[$0] }
          //              .compactMap { state.todos.index(id: $0) }
          //          )
          //          destination =
          //            (destination < filteredTodoIDs.endIndex
          //              ? state.todos.index(id: filteredTodoIDs[destination])
          //              : state.todos.endIndex)
          //            ?? destination
          //        }
          //        state.todos.move(fromOffsets: source, toOffset: destination)
          return .none
          
        case .onAppear:
          return .run { _ in
            var migrator = DatabaseMigrator()
            migrator.registerMigration("Create todos") { db in
              try db.create(table: "todo") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("description", .text)
                t.column("isComplete", .boolean)
              }
            }
            try migrator.migrate(defaultDatabaseQueue)
          }
          
        case .todos:
          return .none
        }
      }
      .forEach(\.todos, action: \.todos) {
        TodoFeature()
      }
    }
    .onChange(of: \.filter) { _, filter in
      Reduce { state, _ in
        let todos = state.todos
        switch filter {
        case .all:
          state.$todos = Shared(
            wrappedValue: todos, .query(Todo.all().order(Column("isComplete").asc))
          )
        case .active:
          state.$todos = Shared(
            wrappedValue: todos, .query(Todo.all().filter(Column("isComplete") == false))
          )
        case .completed:
          state.$todos = Shared(
            wrappedValue: todos, .query(Todo.all().filter(Column("isComplete") == true))
          )
        }
        return .none
      }
    }
  }
}

struct AppView: View {
  @Bindable var store: StoreOf<Todos>

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading) {
        Picker("Filter", selection: $store.filter.animation()) {
          ForEach(Filter.allCases, id: \.self) { filter in
            Text(filter.rawValue).tag(filter)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        List {
          ForEach(store.scope(state: \.todos, action: \.todos), id: \.state.id) { store in
            TodoView(store: store)
          }
          .onDelete { store.send(.delete($0)) }
          .onMove { store.send(.move($0, $1)) }
        }
        .animation(.default, value: store.todos)
      }
      .navigationTitle("Todos")
      .navigationBarItems(
        trailing: HStack(spacing: 20) {
          EditButton()
          Button("Clear Completed") {
            store.send(.clearCompletedButtonTapped, animation: .default)
          }
          .disabled(!store.todos.contains(where: \.isComplete))
          Button("Add Todo") { store.send(.addTodoButtonTapped, animation: .default) }
        }
      )
      .environment(\.editMode, $store.editMode)
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

extension PersistenceKey where Self == FileStorageKey<IdentifiedArrayOf<Todo>> {
  static var todos: Self {
    Self(url: URL.documentsDirectory.appending(path: "todos.json"))
  }
}

extension IdentifiedArrayOf<Todo> {
  static let mock: Self = [
    Todo(
      description: "Check Mail",
      id: 1,
      isComplete: false
    ),
    Todo(
      description: "Buy Milk",
      id: 2,
      isComplete: false
    ),
    Todo(
      description: "Call Mom",
      id: 3,
      isComplete: true
    ),
  ]
}

#Preview {
  AppView(
    store: Store(initialState: Todos.State(todos: .mock)) {
      Todos()
    }
  )
}
