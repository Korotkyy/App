import SwiftUI

// Структура для событий календаря
struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var notes: String
    var time: Date
    
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id  // Сравниваем только по id
    }
}

struct DayView: View {
    let date: Date
    @Binding var selectedEvents: [CalendarEvent]
    let saveEvents: () -> Void
    @State private var showingEventSheet = false
    @State private var newEventTitle = ""
    @State private var newEventNotes = ""
    @State private var newEventTime = Date()
    @State private var isEditing = false
    @State private var editingEvent: CalendarEvent?
    @Environment(\.dismiss) var dismiss
    
    var eventsForDay: [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return selectedEvents.filter { event in
            let eventDate = calendar.startOfDay(for: event.date)
            return eventDate == startOfDay
        }
        .sorted { $0.time < $1.time }
    }
    
    private func deleteEvent(at offsets: IndexSet) {
        let eventsToDelete = offsets.map { eventsForDay[$0] }
        selectedEvents.removeAll { event in
            eventsToDelete.contains { $0.id == event.id }
        }
        saveEvents()
    }
    
    var body: some View {
        ZStack {
            Color.customDarkNavy.ignoresSafeArea()
            
            VStack {
                List {
                    ForEach(eventsForDay) { event in
                        EventRow(event: event) {
                            // Начать редактирование
                            editingEvent = event
                            newEventTitle = event.title
                            newEventNotes = event.notes
                            newEventTime = event.time
                            isEditing = true
                            showingEventSheet = true
                        }
                    }
                    .onDelete(perform: deleteEvent)
                }
                .listStyle(.plain)
                
                // Добавляем кнопку внизу экрана
                Button {
                    editingEvent = nil
                    newEventTitle = ""
                    newEventNotes = ""
                    newEventTime = Date()
                    isEditing = false
                    showingEventSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Event")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.customAccent)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .navigationTitle(date.formatted(date: .complete, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEventSheet) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                    DatePicker("Time", selection: $newEventTime, displayedComponents: [.hourAndMinute])
                    TextField("Notes", text: $newEventNotes)
                }
                .navigationTitle(isEditing ? "Edit Event" : "New Event")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingEventSheet = false
                    },
                    trailing: Button(isEditing ? "Save" : "Add") {
                        if isEditing {
                            if let editingEvent = editingEvent,
                               let index = selectedEvents.firstIndex(where: { $0.id == editingEvent.id }) {
                                var updatedEvent = selectedEvents[index]
                                updatedEvent.title = newEventTitle
                                updatedEvent.notes = newEventNotes
                                updatedEvent.time = newEventTime
                                selectedEvents[index] = updatedEvent
                                saveEvents()
                            }
                        } else {
                            let newEvent = CalendarEvent(
                                id: UUID(),
                                title: newEventTitle,
                                date: date,
                                notes: newEventNotes,
                                time: newEventTime
                            )
                            selectedEvents.append(newEvent)
                            saveEvents()
                        }
                        showingEventSheet = false
                    }
                    .disabled(newEventTitle.isEmpty)
                )
            }
        }
    }
}

// Отдельное представление для строки события
struct EventRow: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(event.time, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.customAccent)
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 5)
            
            Spacer()
            
            // Кнопка редактирования
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.customAccent)
                    .font(.title3)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                // Удаление обрабатывается через onDelete
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct CalendarView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var showingSecondView = false
    @State private var selectedEvents: [CalendarEvent] = []
    @AppStorage("calendarEvents") private var eventsData: Data = Data()
    @State private var showDayView = false
    
    @Binding var savedProjects: [SavedProject]
    @Binding var selectedImage: Image?
    @Binding var goals: [Goal]
    @Binding var cells: [Cell]
    @Binding var showGrid: Bool
    
    private func loadEvents() {
        if let decoded = try? JSONDecoder().decode([CalendarEvent].self, from: eventsData) {
            selectedEvents = decoded
        }
    }
    
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(selectedEvents) {
            eventsData = encoded
        }
    }
    
    var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return selectedEvents.filter { event in
            let eventDate = calendar.startOfDay(for: event.date)
            return eventDate == startOfDay
        }
        .sorted { $0.time < $1.time }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy.ignoresSafeArea()
                
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.customAccent)
                    .padding()
                    .background(Color.customNavy)
                    .cornerRadius(12)
                    .padding()
                    .onChange(of: selectedDate) { _ in
                        showDayView = true
                    }
                    
                    // Список событий под календарем
                    if !eventsForSelectedDate.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Events")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            List {
                                ForEach(eventsForSelectedDate) { event in
                                    Button(action: {
                                        showDayView = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(event.title)
                                                    .font(.system(size: 17, weight: .medium))
                                                    .foregroundColor(.white)
                                                Text(event.time, style: .time)
                                                    .font(.subheadline)
                                                    .foregroundColor(.customAccent)
                                            }
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.customAccent)
                                        }
                                    }
                                    .listRowBackground(Color.customNavy)
                                }
                            }
                            .listStyle(.plain)
                            .frame(height: min(CGFloat(eventsForSelectedDate.count) * 60, 180))
                        }
                        .padding(.top)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Остаемся на текущей странице
                        }) {
                            Label("Calendar", systemImage: "calendar")
                                .foregroundColor(.gray)
                        }
                        .disabled(true)
                        
                        Button(action: {
                            showingSecondView = true
                        }) {
                            Label("My Goals", systemImage: "list.bullet")
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Label("Main", systemImage: "house")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Calendar")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .background(
                NavigationLink(isActive: $showDayView) {
                    DayView(
                        date: selectedDate,
                        selectedEvents: $selectedEvents,
                        saveEvents: saveEvents
                    )
                } label: {
                    EmptyView()
                }
            )
        }
        .sheet(isPresented: $showingSecondView) {
            SecondView(
                savedProjects: $savedProjects,
                selectedImage: $selectedImage,
                goals: $goals,
                isPresented: $showingSecondView,
                cells: $cells,
                showGrid: $showGrid
            )
        }
        .onChange(of: selectedEvents) { _ in
            saveEvents()
        }
        .onAppear {
            loadEvents()
        }
    }
}
