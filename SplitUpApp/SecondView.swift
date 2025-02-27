import SwiftUI

struct SecondView: View {
    @Binding var savedProjects: [SavedProject]
    @Binding var selectedImage: Image?
    @Binding var goals: [Goal]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    @Binding var cells: [Cell]
    @Binding var showGrid: Bool
    @Binding var currentProjectId: UUID?
    
    // Добавляем функцию для сохранения
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(savedProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
            UserDefaults.standard.synchronize() // Принудительно сохраняем
        }
    }
    
    // И добавим функцию загрузки проектов
    private func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: "savedProjects"),
           let decoded = try? JSONDecoder().decode([SavedProject].self, from: data) {
            savedProjects = decoded
        }
    }
    
    private func restoreProject(_ project: SavedProject) {
        if let uiImage = UIImage(data: project.imageData) {
            // Сначала очищаем предыдущее состояние
            selectedImage = nil
            goals.removeAll()
            cells.removeAll()
            
            // Затем восстанавливаем проект
            selectedImage = Image(uiImage: uiImage)
            goals = project.goals
            cells = project.cells
            showGrid = project.showGrid
            currentProjectId = project.id
            isPresented = false
        }
    }
    
    private func getImage(from data: Data) -> Image {
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy  // Заменяем Image("background") на сплошной цвет
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(savedProjects) { project in
                            ZStack(alignment: .topTrailing) {
                                VStack {
                                    getImage(from: project.thumbnailData)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width * 0.4,
                                               height: UIScreen.main.bounds.width * 0.4)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Text(project.projectName)
                                        .font(.system(size: UIScreen.main.bounds.width * 0.035))
                                        .foregroundColor(.white)
                                        .padding(.top, 4)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .background(Color.customNavy)
                                .cornerRadius(10)
                                .onTapGesture {
                                    restoreProject(project)
                                }
                                
                                Button(action: {
                                    if let index = savedProjects.firstIndex(where: { $0.id == project.id }) {
                                        savedProjects.remove(at: index)
                                        saveProjects()
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.red)
                                        .background(Color.white.clipShape(Circle()))
                                }
                                .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .padding()
                    .padding(.top, 60) // Увеличиваем отступ сверху
                }
            }
            .navigationTitle("My Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Остаемся на текущей странице
                        }) {
                            Label("My Goals", systemImage: "list.bullet")
                                .foregroundColor(.gray)
                        }
                        .disabled(true)
                        
                        Button(action: {
                            if let url = URL(string: "https://familykorotkey.github.io/splitup-privacy-policy/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Privacy Policy", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            isPresented = false
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
                    Text("My Goals")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadProjects() // Загружаем все проекты при открытии экрана
        }
    }
}

struct SecondView_Previews: PreviewProvider {
    @State static var mockProjects: [SavedProject] = []
    
    static var previews: some View {
        SecondView(
            savedProjects: .constant([]),  // Пустой массив для превью
            selectedImage: .constant(nil),
            goals: .constant([]),
            isPresented: .constant(true),
            cells: .constant([]),
            showGrid: .constant(true),
            currentProjectId: .constant(nil)
        )
        .previewDevice("iPhone 14")  // Указываем конкретное устройство
    }
}
