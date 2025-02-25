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
    
    // Вычисляемое свойство для отображения прогресса
    var progress: String {
        let total = Int(totalNumber) ?? 0
        let remaining = Int(remainingNumber) ?? 0
        let completed = total - remaining
        return "\(completed)/\(total)\(unit.rawValue)"
    }
}

struct Cell: Codable {
    var isColored: Bool = false
    let position: Int
}

struct SavedProject: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    let goals: [Goal]
    let projectName: String
    let cells: [Cell]
    let showGrid: Bool
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var projectName: String = ""
    @State private var inputText: String = ""
    @State private var inputNumber: String = ""
    @State private var showInputs: Bool = true
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
    
    private var totalSquares: Int {
        goals.reduce(0) { $0 + (Int($1.totalNumber) ?? 0) }
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
        let total = totalSquares
        
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
        // Получаем все незакрашенные позиции
        var availablePositions = cells.enumerated()
            .filter { !$0.element.isColored }
            .map { $0.offset }
        
        // Закрашиваем клетки
        for _ in 0..<min(count, availablePositions.count) {
            guard let randomIndex = availablePositions.indices.randomElement() else { break }
            let position = availablePositions.remove(at: randomIndex)
            cells[position].isColored = true
            coloredCount += 1
        }
        
        // Обновляем состояние цели
        if markAsCompleted,
           let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].isCompleted = true
        }
        
        // Принудительно обновляем отображение
        showGrid = false
        showGrid = true
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(savedProjects) {
            savedProjectsData = encoded
        }
    }
    
    private func loadFromStorage() {
        if let decoded = try? JSONDecoder().decode([SavedProject].self, from: savedProjectsData) {
            savedProjects = decoded
        }
    }
    
    private func convertImageToData(_ image: Image) -> Data? {
        // Создаем UIImage из Image
        let controller = UIHostingController(rootView:
            image
                .resizable()
                .scaledToFill()
                .frame(width: 300, height: 300)
                .clipped()
                .background(Color.clear)
        )
        controller.view.backgroundColor = .clear
        
        // Устанавливаем размер
        let size = CGSize(width: 300, height: 300)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        
        // Создаем контекст для рендеринга
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        // Рендерим изображение
        let uiImage = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        
        // Конвертируем в PNG для сохранения прозрачности
        return uiImage.pngData()
    }
    
    private func saveProject() {
        if let image = selectedImage {
            if let imageData = convertImageToData(image) {
                let projectTitle = projectName.isEmpty ? goals.first?.text ?? "Untitled" : projectName
                let newProject = SavedProject(
                    id: UUID(),
                    imageData: imageData,
                    goals: goals,
                    projectName: projectTitle,
                    cells: cells,     // Сохраняем клетки
                    showGrid: showGrid // Сохраняем состояние сетки
                )
                savedProjects.append(newProject)
                saveToStorage()
                showingSecondView = true
            }
        }
    }
    
    private func getImage(from data: Data) -> Image {
        if let uiImage = UIImage(data: data)?.preparingForDisplay() {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy
                    .ignoresSafeArea()
                
                VStack(spacing: 10) {
                    if let image = selectedImage {
                        HStack(spacing: 20) {
                            Button(action: {
                                saveProject()
                            }) {
                                Text("Save")
                                    .fontWeight(.bold)
                                    .foregroundColor(.customDarkNavy)
                                    .frame(width: UIScreen.main.bounds.width * 0.25, height: 40)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                selectedImage = nil
                                selectedItem = nil
                                goals.removeAll()
                                showGrid = false
                                savedState = nil
                                cells.removeAll()
                                coloredCount = 0
                                clearInputs()
                            }) {
                                Text("Delete")
                                    .fontWeight(.bold)
                                    .foregroundColor(.customBeige)
                                    .frame(width: 100, height: 40)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.vertical, 5)
                        
                        // Обновите TextField
                        TextField("Project name", text: $projectName)
                            .textFieldStyle(CustomTextFieldStyle())
                            .padding(.horizontal)
                            .padding(.vertical, 5)
                            .multilineTextAlignment(.center)
                        
                        ZStack {
                            GeometryReader { geometry in
                                ZStack {
                                    if let image = selectedImage {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .clipped()
                                            .grayscale(1.0)
                                    }
                                    
                                    if showGrid && selectedImage != nil {
                                        let dimensions = calculateGridDimensions()
                                        let width = geometry.size.width / CGFloat(dimensions.columns)
                                        let height = geometry.size.height / CGFloat(dimensions.rows)
                                        
                                        // Цветные клетки поверх черно-белого изображения
                                        ForEach(0..<cells.count, id: \.self) { index in
                                            let row = index / dimensions.columns
                                            let col = index % dimensions.columns
                                            if cells[index].isColored {
                                                if let image = selectedImage {
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                                        .clipped()
                                                        .mask(
                                                            Rectangle()
                                                                .frame(width: width, height: height)
                                                                .position(
                                                                    x: width * CGFloat(col) + width/2,
                                                                    y: height * CGFloat(row) + height/2
                                                                )
                                                        )
                                                }
                                            }
                                        }
                                        
                                        // Белая сетка только для незакрашенных клеток
                                        ForEach(0..<cells.count, id: \.self) { index in
                                            let row = index / dimensions.columns
                                            let col = index % dimensions.columns
                                            if !cells[index].isColored {
                                                Rectangle()
                                                    .stroke(Color.white, lineWidth: 1)
                                                    .frame(width: width, height: height)
                                                    .position(
                                                        x: width * CGFloat(col) + width/2,
                                                        y: height * CGFloat(row) + height/2
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.95)
                        .frame(height: UIScreen.main.bounds.height * 0.4)
                        .padding(.horizontal)
                        
                        // Обновим отображение общей суммы
                        HStack(spacing: 20) {
                            Text("Total: \(goals.reduce(0) { $0 + (Int($1.totalNumber) ?? 0) })")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.customBeige)
                            
                            Text("Remaining: \(goals.reduce(0) { $0 + (Int($1.remainingNumber) ?? 0) })")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.customBeige)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.customNavy)
                        .cornerRadius(12)
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 20) {
                                Button(action: {
                                    isEditing ? updateGoal() : addGoal()
                                    showInputs = true
                                }) {
                                    Text(isEditing ? "Update" : "Add")
                                        .foregroundColor(.customDarkNavy)
                                        .frame(width: 100, height: 35)
                                        .background(Color.customBeige)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    showGrid = true
                                    showInputs = false
                                    initializeCells()
                                }) {
                                    HStack {
                                        Image(systemName: "grid")
                                            .font(.system(size: 18))
                                        Text("Divide Image")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(.customDarkNavy)
                                    .frame(width: 140, height: 35)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                                }
                            }
                            
                            if showInputs {
                                VStack(spacing: 10) {
                                    TextField("Enter text", text: $inputText)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .padding(.horizontal)
                                        .background(Color.customBeige.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                        )
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("Done") {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                                                }
                                            }
                                        }
                                    
                                    HStack {
                                        TextField("Enter number", text: $inputNumber)
                                            .textFieldStyle(CustomTextFieldStyle())
                                            .keyboardType(.numberPad)
                                            .padding(.horizontal)
                                            .background(Color.customBeige.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                            )
                                            .toolbar {
                                                ToolbarItemGroup(placement: .keyboard) {
                                                    Spacer()
                                                    Button("Done") {
                                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)
                                                    }
                                                }
                                            }
                                        
                                        Picker("Unit", selection: $selectedUnit) {
                                            Section(header: Text("Количество").foregroundColor(.gray)) {
                                                ForEach([GoalUnit.pieces, .packs, .kilograms, .liters, .meters], id: \.self) { unit in
                                                    Text(unit.rawValue).tag(unit)
                                                }
                                            }
                                            
                                            Section(header: Text("Деньги").foregroundColor(.gray)) {
                                                ForEach([GoalUnit.euro, .dollar, .ruble, .tenge], id: \.self) { unit in
                                                    Text(unit.rawValue).tag(unit)
                                                }
                                            }
                                            
                                            Section(header: Text("Время").foregroundColor(.gray)) {
                                                ForEach([GoalUnit.days, .weeks, .months, .hours], id: \.self) { unit in
                                                    Text(unit.rawValue).tag(unit)
                                                }
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 80)
                                        .background(Color.customBeige)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            
                            HStack {
                                Button(action: {
                                    if let goal = goals[safe: selectedGoalIndex] {
                                        withAnimation {
                                            goals.remove(at: selectedGoalIndex)
                                            if selectedGoalIndex >= goals.count {
                                                selectedGoalIndex = max(goals.count - 1, 0)
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 20))
                                }
                                
                                Picker("Goals", selection: $selectedGoalIndex) {
                                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                                        HStack(spacing: 4) {
                                            Text("\(goal.text)")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(.white)
                                                .strikethrough(goal.isCompleted)
                                                .lineLimit(1)
                                            
                                            Text(goal.progress)
                                                .font(.system(size: 15, weight: .regular))
                                                .foregroundColor(.customAccent)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .tag(index)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .overlay(
                                    Button(action: {
                                        showGoalsList = true
                                    }) {
                                        Color.clear
                                            .frame(width: UIScreen.main.bounds.width * 0.5)
                                    }
                                )
                                
                                if let goal = goals[safe: selectedGoalIndex],
                                   !goal.isCompleted {
                                    Button(action: {
                                        if !showGrid {
                                            showAlert = true
                                        } else {
                                            withAnimation {
                                                if let remainingAmount = Int(goal.remainingNumber) {
                                                    goals[selectedGoalIndex].remainingNumber = "0"
                                                    goals[selectedGoalIndex].isCompleted = true
                                                    
                                                    let goalCells = getCellsForGoal(goal)
                                                    colorRandomCells(count: remainingAmount, 
                                                                   goalId: goal.id, 
                                                                   markAsCompleted: true)
                                                }
                                            }
                                        }
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(showGrid ? .green : .green.opacity(0.3))
                                            .font(.system(size: 20))
                                    }
                                    .disabled(!showGrid)
                                }
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.08)
                            .background(Color.customNavy)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .alert(isPresented: $showAlert) {
                                Alert(
                                    title: Text("Image Not Divided"),
                                    message: Text("Please divide the image first by clicking 'Divide Image' button."),
                                    dismissButton: .default(Text("OK"))
                                )
                            }
                            
                            if let selectedGoal = goals[safe: selectedGoalIndex],
                               !selectedGoal.isCompleted && showGrid {
                                HStack(spacing: 15) {
                                    TextField("Enter completed amount", text: $partialCompletion)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .keyboardType(.numberPad)
                                        .padding(.horizontal)
                                        .frame(width: UIScreen.main.bounds.width * 0.35)
                                        .background(Color.customBeige.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                        )
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("Done") {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                                                }
                                            }
                                        }
                                    
                                    Button("Complete") {
                                        if let partialAmount = Int(partialCompletion),
                                           let remainingAmount = Int(selectedGoal.remainingNumber),
                                           partialAmount <= remainingAmount {
                                            let newRemaining = remainingAmount - partialAmount
                                            
                                            if let index = goals.firstIndex(where: { $0.id == selectedGoal.id }) {
                                                goals[index].remainingNumber = String(newRemaining)
                                                goals[index].isCompleted = newRemaining == 0
                                                
                                                let goalCells = getCellsForGoal(selectedGoal)
                                                let proportion = Double(partialAmount) / Double(Int(selectedGoal.totalNumber) ?? 1)
                                                let cellsToColor = Int(Double(goalCells) * proportion)
                                                colorRandomCells(count: cellsToColor, goalId: selectedGoal.id, markAsCompleted: newRemaining == 0)
                                            }
                                            partialCompletion = ""
                                        }
                                    }
                                    .foregroundColor(.customDarkNavy)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 5)
                    } else {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images
                        ) {
                            VStack {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.customBeige)
                                
                                Text("Upload Image")
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
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingSecondView = true
                        }) {
                            Label("My Goals", systemImage: "list.bullet")
                        }
                        
                        Button(action: {
                            openPrivacyPolicy()
                        }) {
                            Label("Privacy Policy", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            selectedImage = nil
                            selectedItem = nil
                            goals.removeAll()
                            showGrid = false
                            savedState = nil
                            cells.removeAll()
                            coloredCount = 0
                            clearInputs()
                        }) {
                            Label("Main", systemImage: "house")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
            }
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
        .sheet(isPresented: $showGoalsList) {
            NavigationView {
                List {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        HStack {
                            Button(action: {
                                selectedGoalIndex = index
                                showGoalsList = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(goal.text)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                            .strikethrough(goal.isCompleted)
                                        
                                        Text(goal.progress)
                                            .font(.system(size: 15))
                                            .foregroundColor(.customAccent)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            if !goal.isCompleted {
                                Button(action: {
                                    if showGrid {
                                        withAnimation {
                                            if let remainingAmount = Int(goal.remainingNumber) {
                                                goals[index].remainingNumber = "0"
                                                goals[index].isCompleted = true
                                                
                                                let goalCells = getCellsForGoal(goal)
                                                colorRandomCells(count: remainingAmount, 
                                                               goalId: goal.id, 
                                                               markAsCompleted: true)
                                            }
                                        }
                                    } else {
                                        showAlert = true
                                    }
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(showGrid ? .green : .green.opacity(0.3))
                                        .font(.system(size: 20))
                                }
                                .disabled(!showGrid)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                            }
                        }
                        .listRowBackground(Color.customNavy)
                    }
                }
                .listStyle(.plain)
                .background(Color.customDarkNavy)
                .navigationTitle("Goals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showGoalsList = false
                        }
                        .foregroundColor(.white)
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Image Not Divided"),
                        message: Text("Please divide the image first by clicking 'Divide Image' button."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: selectedItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = Image(uiImage: uiImage)
                }
            }
        }
        .onAppear {
            loadFromStorage()
        }
    }
    
    private func addGoal() {
        if !inputText.isEmpty && !inputNumber.isEmpty {
            goals.append(Goal(
                text: inputText,
                totalNumber: inputNumber,
                remainingNumber: inputNumber,
                unit: selectedUnit
            ))
            clearInputs()
        }
    }
    
    private func startEditing(_ goal: Goal) {
        editingGoal = goal
        inputText = goal.text
        inputNumber = goal.totalNumber
        isEditing = true
    }
    
    private func updateGoal() {
        if let editingGoal = editingGoal,
           let index = goals.firstIndex(where: { $0.id == editingGoal.id }) {
            goals[index] = Goal(
                text: inputText,
                totalNumber: inputNumber,
                remainingNumber: inputNumber,
                unit: selectedUnit
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
        if let goalNumber = Int(goal.totalNumber) {
            return goalNumber
        }
        return 0
    }
    
    // Добавим новую функцию для восстановления состояния сетки
    private func restoreGridState(from project: SavedProject) {
        selectedImage = getImage(from: project.imageData)
        goals = project.goals
        cells = project.cells
        showGrid = project.showGrid
        coloredCount = project.cells.filter { $0.isColored }.count
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://familykorotkey.github.io/splitup-privacy-policy/") {
            UIApplication.shared.open(url)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("Default")
                .previewLayout(.device)
                .preferredColorScheme(.light)
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

