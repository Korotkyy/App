import SwiftUI

// Структура для событий календаря
struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var notes: String
    var time: Date
    
    // Добавляем реализацию Equatable
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

struct DayView: View {
    let date: Date
    @Binding var selectedEvents: [CalendarEvent]
    @State private var showingEventSheet = false
    @State private var newEventTitle = ""
    @State private var newEventNotes = ""
    @State private var newEventTime = Date()
    @Environment(\.dismiss) var dismiss
    
    var eventsForDay: [CalendarEvent] {
        selectedEvents.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    var body: some View {
        ZStack {
            Color.customDarkNavy.ignoresSafeArea()
            
            VStack {
                List {
                    ForEach(eventsForDay) { event in
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
                    }
                    .onDelete(perform: deleteEvent)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(date.formatted(date: .complete, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEventSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.customAccent)
                }
            }
        }
        .sheet(isPresented: $showingEventSheet) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                    DatePicker("Time", selection: $newEventTime, displayedComponents: [.hourAndMinute])
                    TextField("Notes", text: $newEventNotes)
                }
                .navigationTitle("New Event")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingEventSheet = false
                    },
                    trailing: Button("Add") {
                        let newEvent = CalendarEvent(
                            id: UUID(),
                            title: newEventTitle,
                            date: date,
                            notes: newEventNotes,
                            time: newEventTime
                        )
                        selectedEvents.append(newEvent)
                        showingEventSheet = false
                        newEventTitle = ""
                        newEventNotes = ""
                    }
                    .disabled(newEventTitle.isEmpty)
                )
            }
        }
    }
    
    private func deleteEvent(at offsets: IndexSet) {
        for index in offsets {
            if let eventToDelete = eventsForDay[safe: index],
               let indexInMainArray = selectedEvents.firstIndex(where: { $0.id == eventToDelete.id }) {
                selectedEvents.remove(at: indexInMainArray)
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
                    .padding()
                    .background(Color.customNavy)
                    .cornerRadius(12)
                    .padding()
                    .onChange(of: selectedDate) { _ in
                        showDayView = true
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
                        selectedEvents: $selectedEvents
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
