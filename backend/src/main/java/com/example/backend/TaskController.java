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
            data.put("id", doc.getId());
            result.add(data);
        }
        return result;
    }

    @PostMapping
    public String createTask(@RequestBody Map<String, Object> task) {
        db.collection("tasks").add(task);
        return "Task created";
    }

    @DeleteMapping("/{id}")
    public String deleteTask(@PathVariable String id) throws ExecutionException, InterruptedException {
        db.collection("tasks").document(id).delete();
        return "Task deleted";
    }
}