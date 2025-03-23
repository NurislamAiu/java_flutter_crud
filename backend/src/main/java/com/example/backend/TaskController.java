package com.example.backend;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.google.firebase.cloud.FirestoreClient;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.concurrent.ExecutionException;

@RestController
@RequestMapping("/api/tasks")
@CrossOrigin
public class TaskController {

    private final Firestore db = FirestoreClient.getFirestore();

    @GetMapping
    public List<Map<String, Object>> getAllTasks() throws ExecutionException, InterruptedException {
        List<Map<String, Object>> result = new ArrayList<>();
        ApiFuture<QuerySnapshot> future = db.collection("tasks").get();
        for (DocumentSnapshot doc : future.get().getDocuments()) {
            Map<String, Object> data = doc.getData();
            assert data != null;
            data.put("id", doc.getId());
            result.add(data);
        }
        return result;
    }

    @PostMapping
    public String createTask(@RequestBody Map<String, Object> taskData) throws Exception {
        Map<String, Object> docData = new HashMap<>();
        docData.put("title", taskData.get("title"));
        docData.put("description", taskData.get("description"));
        docData.put("completed", taskData.getOrDefault("completed", false));
        docData.put("category", taskData.getOrDefault("category", "Общее"));
        docData.put("createdAt", FieldValue.serverTimestamp());

        db.collection("tasks").add(docData);
        return "Task created";
    }

    @DeleteMapping("/{id}")
    public String deleteTask(@PathVariable String id) throws ExecutionException, InterruptedException {
        db.collection("tasks").document(id).delete();
        return "Task deleted";
    }

    @PutMapping("/{id}")
    public String updateTask(@PathVariable String id, @RequestBody Map<String, Object> updatedData)
            throws ExecutionException, InterruptedException {
        DocumentReference docRef = db.collection("tasks").document(id);

        Map<String, Object> updates = new HashMap<>();
        if (updatedData.containsKey("title")) {
            updates.put("title", updatedData.get("title"));
        }
        if (updatedData.containsKey("description")) {
            updates.put("description", updatedData.get("description"));
        }
        if (updatedData.containsKey("completed")) {
            updates.put("completed", updatedData.get("completed"));
        }
        if (updatedData.containsKey("category")) {
            updates.put("category", updatedData.get("category"));
        }

        docRef.update(updates);
        return "Task updated";
    }
}