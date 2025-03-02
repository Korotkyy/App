//
//  ContentView.swift
//  SplitUp
//
//  Created by FamilyKorotkey on 11.02.25.
//

import SwiftUI
import PhotosUI

enum GoalUnit: String, Codable, Identifiable, CaseIterable {
    // Количественные
    case pieces = "шт"
    case packs = "уп"
    case kilograms = "кг"
    case liters = "л"
    case meters = "м"
    
    // Денежные
    case euro = "€"
    case dollar = "$"
    case ruble = "₽"
    case tenge = "₸"
    
    // Временные
    case days = "дн"
    case weeks = "нед"
    case months = "мес"
    case hours = "ч"
    
    var id: String { self.rawValue }
}

struct Goal: Identifiable, Codable {
    var id = UUID()
    var text: String
    var totalNumber: String        // Общая сумма цели
    var remainingNumber: String    // Оставшаяся сумма
    var isCompleted: Bool = false
    var unit: GoalUnit
    var scale: Int = 1 // Добавляем масштаб: сколько единиц в одном квадрате
    
    // Вычисляемое свойство для отображения прогресса
    var progress: String {
        let total = Int(totalNumber) ?? 0
        let remaining = Int(remainingNumber) ?? 0
        let completed = total - remaining
        
        // Показываем масштаб только если он больше 1
        let scaleText = scale > 1 ? " (1□=\(scale)\(unit.rawValue))" : ""
        return "\(completed)/\(total)\(unit.rawValue)\(scaleText)"
    }
    
    // Добавляем вычисляемое свойство для реального количества квадратов
    var scaledSquares: Int {
        let total = Int(totalNumber) ?? 0
        return Int(ceil(Double(total) / Double(scale)))
    }
}

struct Cell: Codable {
    var isColored: Bool = false
    let position: Int
}

struct SavedProject: Identifiable, Codable {
    let id: UUID
    let imageData: Data        // Оригинальное изображение
    let thumbnailData: Data    // Маленькое изображение для превью
    let goals: [Goal]
    let projectName: String
    let cells: [Cell]
    let showGrid: Bool
    let deadline: Date?  // Добавляем опциональную дату дедлайна
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image? = nil
    @State private var projectName: String = ""
    @State private var selectedDeadline: Date?
    @State private var showDatePicker = false
    @State private var inputText: String = ""
    @State private var inputNumber: String = ""
    @State private var showInputs: Bool = false
    @State private var goals: [Goal] = []
    @State private var editingGoal: Goal?
    @State private var isEditing = false
    @State private var showGrid = false
    @State private var savedState: (Image?, [Goal])?
    @State private var cells: [Cell] = []
    @State private var coloredCount: Int = 0
    @State private var selectedGoalIndex = 0
    @State private var partialCompletion: String = ""
    @State private var savedProjects: [SavedProject] = []
    @State private var showingSecondView = false
    @AppStorage("savedProjects") private var savedProjectsData: Data = Data()
    @State private var showAlert = false
    @State private var selectedUnit: GoalUnit = .pieces
    @State private var showGoalsList = false
    @State private var showEditForm = false
    @State private var showingCalendar = false
    @State private var lastCellsState: [Cell]?
    @State private var lastGoalsState: [Goal]?
    @State private var currentProjectId: UUID?
    @State private var originalImageData: Data?
    @State private var originalUIImage: UIImage?
    @State private var isLayoutReady: Bool = false
    @State private var showActionButtons = true
    
    private var totalSquares: Int {
        goals.reduce(0) { $0 + $1.scaledSquares }
    }
    
    private func calculateGridDimensions() -> (rows: Int, columns: Int) {
        let total = totalSquares
        guard total > 0 else { return (0, 0) }
        
        let sqrt = Double(total).squareRoot()
        let columns = Int(ceil(sqrt))
        let rows = Int(ceil(Double(total) / Double(columns)))
        
        return (rows, columns)
    }
    
    private func initializeCells() {
        let totalSum = goals.reduce(0) { $0 + (Int($1.totalNumber) ?? 0) }
        let scale = calculateScale(for: totalSum)
        
        // Если общая сумма превышает 10000, обновляем масштаб для всех целей
        if totalSum > 10000 {
            for (index, _) in goals.enumerated() {
                goals[index].scale = scale
            }
        }
        
        // Теперь используем scaledSquares для определения общего количества ячеек
        let total = goals.reduce(0) { $0 + $1.scaledSquares }
        
        // Сохраняем текущие закрашенные клетки
        let existingColoredCells = cells.filter { $0.isColored }
        
        // Создаем новую сетку
        cells = Array(0..<total).map { position in
            // Проверяем, была ли эта клетка закрашена раньше
            if existingColoredCells.contains(where: { $0.position == position }) {
                return Cell(isColored: true, position: position)
            }
            return Cell(isColored: false, position: position)
        }
        
        coloredCount = cells.filter { $0.isColored }.count
    }
    
    private func colorRandomCells(count: Int, goalId: UUID, markAsCompleted: Bool = false) {
        if let goal = goals.first(where: { $0.id == goalId }) {
            // Получаем все незакрашенные клетки на всем изображении
        var availablePositions = cells.enumerated()
            .filter { !$0.element.isColored }
            .map { $0.offset }
        
            // Рассчитываем, сколько клеток нужно закрасить
            let totalAmount = Double(Int(goal.totalNumber) ?? 0)
            let proportion = Double(count) / totalAmount
            let cellsToColor = Int(ceil(Double(goal.scaledSquares) * proportion))
            
            // Закрашиваем клетки случайным образом по всему изображению
            for _ in 0..<min(cellsToColor, availablePositions.count) {
            guard let randomIndex = availablePositions.indices.randomElement() else { break }
            let position = availablePositions.remove(at: randomIndex)
            cells[position].isColored = true
            coloredCount += 1
        }
        
            // Обновляем отображение
            showGrid = false
            showGrid = true
        }
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(savedProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
            UserDefaults.standard.synchronize() // Принудительно сохраняем
        }
    }
    
    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "savedProjects"),
           let decoded = try? JSONDecoder().decode([SavedProject].self, from: data) {
            savedProjects = decoded
        }
    }
    
    private func convertImageToData(_ image: Image?) -> Data? {
        guard let image = image else { return nil }
        
        // Получаем UIImage напрямую из PhotosPicker
        if let uiImage = image.asUIImage() {
            // Сохраняем в максимальном качестве
            return uiImage.jpegData(compressionQuality: 1.0)
        }
        
        return nil
    }
    
    private func saveProject() {
        guard let uiImage = originalUIImage else { return }
        
                let projectTitle = projectName.isEmpty ? goals.first?.text ?? "Untitled" : projectName
        let imageData = uiImage.jpegData(compressionQuality: 1.0)!
        
        var existingProjects: [SavedProject] = []
        if let data = UserDefaults.standard.data(forKey: "savedProjects"),
           let decoded = try? JSONDecoder().decode([SavedProject].self, from: data) {
            existingProjects = decoded
        }
        
        if let currentId = currentProjectId,
           let existingIndex = existingProjects.firstIndex(where: { $0.id == currentId }) {
            let updatedProject = SavedProject(
                id: currentId,
                imageData: imageData,
                thumbnailData: createThumbnail(from: uiImage) ?? imageData,
                goals: goals,
                projectName: projectTitle,
                cells: cells,
                showGrid: showGrid,
                deadline: selectedDeadline  // Добавляем дедлайн
            )
            existingProjects[existingIndex] = updatedProject
        } else {
            let newId = UUID()
                let newProject = SavedProject(
                id: newId,
                    imageData: imageData,
                thumbnailData: createThumbnail(from: uiImage) ?? imageData,
                    goals: goals,
                    projectName: projectTitle,
                cells: cells,
                showGrid: showGrid,
                deadline: selectedDeadline  // Добавляем дедлайн
                )
            existingProjects.append(newProject)
            currentProjectId = newId
            }
        
        if let encoded = try? JSONEncoder().encode(existingProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
            UserDefaults.standard.synchronize()
            savedProjects = existingProjects
        }
        
        showingSecondView = true
    }
    
    private func getImage(from data: Data) -> Image {
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo") // Возвращаем placeholder вместо nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: selectedImage == nil ? 20 : 10) {
                        if selectedImage == nil {
                            MainMenuView(
                                showingCalendar: $showingCalendar,
                                selectedItem: $selectedItem,
                                showingSecondView: $showingSecondView
                            )
                    } else {
                            ImageEditView(
                                selectedImage: $selectedImage,
                                selectedItem: $selectedItem,
                                goals: $goals,
                                showGrid: $showGrid,
                                cells: $cells,
                                coloredCount: $coloredCount,
                                showInputs: $showInputs,
                                inputText: $inputText,
                                inputNumber: $inputNumber,
                                selectedUnit: $selectedUnit,
                                selectedGoalIndex: $selectedGoalIndex,
                                showActionButtons: $showActionButtons,
                                selectedDeadline: $selectedDeadline,
                                projectName: $projectName,
                                showDatePicker: $showDatePicker,
                                showAlert: $showAlert,
                                lastCellsState: $lastCellsState,
                                lastGoalsState: $lastGoalsState,
                                partialCompletion: $partialCompletion
                            )
                        }
                    }
                }
                .onChange(of: selectedImage) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            isLayoutReady = true
                        }
                    }
                }
                .onAppear {
                    loadFromStorage()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            isLayoutReady = true
                        }
                    }
                }
                .id(isLayoutReady)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSecondView) {
            SecondView(
                savedProjects: $savedProjects,
                selectedImage: $selectedImage,
                goals: $goals,
                isPresented: $showingSecondView,
                cells: $cells,
                showGrid: $showGrid,
                currentProjectId: $currentProjectId,
                projectName: $projectName,
                originalUIImage: $originalUIImage
            )
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView(
                savedProjects: $savedProjects,
                selectedImage: $selectedImage,
                goals: $goals,
                cells: $cells,
                showGrid: $showGrid
            )
        }
        .onChange(of: selectedItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    goals.removeAll()
                    cells.removeAll()
                    currentProjectId = nil
                    originalUIImage = uiImage
                    selectedImage = Image(uiImage: uiImage)
                }
            }
        }
    }
    
    private func addGoal() {
        guard !inputText.isEmpty && !inputNumber.isEmpty,
              let number = Int(inputNumber),
              number > 0 else { return }
        
        let scale = calculateScale(for: number)
        
        withAnimation {
            goals.append(Goal(
                text: inputText,
                totalNumber: inputNumber,
                remainingNumber: inputNumber,
                unit: selectedUnit,
                scale: scale
            ))
            clearInputs()
            showInputs = false
        }
    }
    
    private func startEditing(_ goal: Goal) {
        editingGoal = goal
        inputText = goal.text
        inputNumber = goal.totalNumber
        selectedUnit = goal.unit
        isEditing = true
        showEditForm = true
    }
    
    private func updateGoal() {
        if let editingGoal = editingGoal,
           let index = goals.firstIndex(where: { $0.id == editingGoal.id }) {
            goals[index] = Goal(
                id: editingGoal.id, // Сохраняем тот же id
                text: inputText,
                totalNumber: inputNumber,
                remainingNumber: inputNumber,
                unit: selectedUnit,
                scale: editingGoal.scale
            )
            clearInputs()
            isEditing = false
            self.editingGoal = nil
        }
    }
    
    private func clearInputs() {
        inputText = ""
        inputNumber = ""
    }
    
    private func getCellsForGoal(_ goal: Goal) -> Int {
        return goal.scaledSquares
    }
    
    // Добавим новую функцию для восстановления состояния сетки
    private func restoreGridState(from project: SavedProject) {
        if let uiImage = UIImage(data: project.imageData) {
            originalUIImage = uiImage
            selectedImage = Image(uiImage: uiImage)
        goals = project.goals
        cells = project.cells
        showGrid = project.showGrid
            projectName = project.projectName
            currentProjectId = project.id
            selectedDeadline = project.deadline  // Восстанавливаем дедлайн
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isLayoutReady = true
                }
            }
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://familykorotkey.github.io/splitup-privacy-policy/") {
            UIApplication.shared.open(url)
        }
    }
    
    // Функция для автоматического определения масштаба
    private func calculateScale(for number: Int) -> Int {
        if number <= 10000 { return 1 }
        else if number <= 100000 { return 10 }
        else if number <= 1000000 { return 100 }
        else if number <= 10000000 { return 1000 }
        else { return 10000 }
    }
    
    private func updateGoalProgress(goalId: UUID, amount: Int) {
        guard let goalIndex = goals.firstIndex(where: { $0.id == goalId }),
              let remainingAmount = Int(goals[goalIndex].remainingNumber),
              amount > 0,
              amount <= remainingAmount else { return }
        
        // Сохраняем текущее состояние перед изменением
        lastCellsState = cells
        lastGoalsState = goals
        
        withAnimation {
            // Обновляем состояние цели
            let newRemaining = remainingAmount - amount
            goals[goalIndex].remainingNumber = String(newRemaining)
            goals[goalIndex].isCompleted = newRemaining == 0
            
            // Закрашиваем клетки
            let scale = goals[goalIndex].scale
            let cellsToColor = Int(ceil(Double(amount) / Double(scale)))
            
            var availablePositions = cells.enumerated()
                .filter { !$0.element.isColored }
                .map { $0.offset }
                .shuffled()
            
            for _ in 0..<min(cellsToColor, availablePositions.count) {
                guard let position = availablePositions.popLast() else { break }
                cells[position].isColored = true
            }
            
            coloredCount = cells.filter { $0.isColored }.count
        }
    }
    
    // Добавляем функцию создания миниатюры
    private func createThumbnail(from image: UIImage) -> Data? {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail?.jpegData(compressionQuality: 0.7)
    }
    
    // Добавим вычисляемое свойство для отображения оставшихся дней
    private var daysRemaining: String {
        guard let deadline = selectedDeadline else { return "Date" }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return "Date" }
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
    
    // Добавляем новую функцию для форматирования оставшихся дней
    private func getRemainingDays(_ deadline: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return "" }
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day left"
        } else if days < 0 {
            return "Overdue"
        } else {
            return "\(days) days left"
        }
    }
}

// Вспомогательное представление для главного меню
struct MainMenuView: View {
    @Binding var showingCalendar: Bool
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var showingSecondView: Bool
    
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 50)
            
            Button(action: { showingCalendar = true }) {
                VStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 30))
                        .foregroundColor(.customBeige)
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.customBeige)
                }
                .frame(width: 160, height: 100)
                .background(Color.customNavy)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.bottom, 20)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.customBeige)
                    
                    Text("New Goal")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.customBeige)
                }
                .frame(width: 160, height: 100)
                .background(Color.customNavy)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.bottom, 20)
            
            Button(action: { showingSecondView = true }) {
                VStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 30))
                        .foregroundColor(.customBeige)
                    
                    Text("My Goals")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.customBeige)
                }
                .frame(width: 160, height: 100)
                .background(Color.customNavy)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// Вспомогательное представление для редактирования изображения
struct ImageEditView: View {
    // Добавьте все необходимые @Binding свойства
    @Binding var selectedImage: Image?
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var goals: [Goal]
    @Binding var showGrid: Bool
    @Binding var cells: [Cell]
    @Binding var coloredCount: Int
    @Binding var showInputs: Bool
    @Binding var inputText: String
    @Binding var inputNumber: String
    @Binding var selectedUnit: GoalUnit
    @Binding var selectedGoalIndex: Int
    @Binding var showActionButtons: Bool
    @Binding var selectedDeadline: Date?
    @Binding var projectName: String
    @Binding var showDatePicker: Bool
    @Binding var showAlert: Bool
    @Binding var lastCellsState: [Cell]?
    @Binding var lastGoalsState: [Goal]?
    @Binding var partialCompletion: String
    
    var body: some View {
        // Добавьте содержимое из основного представления, относящееся к редактированию изображения
        Text("Image Edit View")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
            ContentView()
            .previewDevice("iPhone 14")
            .previewDisplayName("iPhone 14")
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView:
            self
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
        )
        
        let view = controller.view
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
        }
    }
}

