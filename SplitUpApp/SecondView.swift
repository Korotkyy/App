import SwiftUI

struct SecondView: View {
    @Binding var savedProjects: [SavedProject]
    @Binding var selectedImage: Image?
    @Binding var goals: [Goal]
    @Binding var isPresented: Bool
    @Binding var cells: [Cell]
    @Binding var showGrid: Bool
    @Binding var currentProjectId: UUID?
    @Binding var projectName: String
    @Binding var originalUIImage: UIImage?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(savedProjects) { project in
                    Button(action: {
                        loadProject(project)
                        isPresented = false
                    }) {
                        HStack {
                            if let imageData = project.thumbnailData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(project.projectName)
                                    .font(.headline)
                                    .foregroundColor(.customBeige)
                                
                                Text("\(project.goals.count) goals")
                                    .font(.subheadline)
                                    .foregroundColor(.customBeige.opacity(0.7))
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .onDelete(perform: deleteProject)
            }
            .listStyle(.plain)
            .background(Color.customDarkNavy)
            .navigationTitle("Saved Projects")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func loadProject(_ project: SavedProject) {
        if let uiImage = UIImage(data: project.imageData) {
            originalUIImage = uiImage
            selectedImage = Image(uiImage: uiImage)
            goals = project.goals
            cells = project.cells
            showGrid = project.showGrid
            projectName = project.projectName
            currentProjectId = project.id
        }
    }
    
    private func deleteProject(at offsets: IndexSet) {
        savedProjects.remove(atOffsets: offsets)
        if let encoded = try? JSONEncoder().encode(savedProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
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
            currentProjectId: .constant(nil),
            projectName: .constant(""),
            originalUIImage: .constant(nil)
        )
        .previewDevice("iPhone 14")  // Указываем конкретное устройство
    }
}
