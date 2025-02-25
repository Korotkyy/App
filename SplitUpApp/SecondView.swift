import SwiftUI

struct SecondView: View {
    @Binding var savedProjects: [SavedProject]
    @Binding var selectedImage: Image?
    @Binding var goals: [Goal]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    @Binding var cells: [Cell]
    @Binding var showGrid: Bool
    
    // Добавляем функцию для сохранения
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(savedProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
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
                Image("background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .ignoresSafeArea()
                    .overlay(
                        Color.brown.opacity(0.1)
                    )
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(savedProjects) { project in
                            ZStack(alignment: .topTrailing) {
                                VStack {
                                    getImage(from: project.imageData)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width * 0.4,   // Пропорциональные размеры
                                               height: UIScreen.main.bounds.width * 0.4)  // Квадратная форма
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Text(project.projectName)
                                        .font(.system(size: UIScreen.main.bounds.width * 0.035))  // Адаптивный размер шрифта
                                        .foregroundColor(.white)
                                        .padding(.top, 4)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .onTapGesture {
                                    selectedImage = getImage(from: project.imageData)
                                    goals = project.goals
                                    cells = project.cells
                                    showGrid = project.showGrid
                                    dismiss()
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
                    .padding(.top, 30)
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
            showGrid: .constant(true)
        )
        .previewDevice("iPhone 14")  // Указываем конкретное устройство
    }
}
