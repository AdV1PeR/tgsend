#include <iostream>
using namespace std;

// Структура узла двунаправленной очереди
struct Node {
    int data;       // Значение элемента
    Node* prev;     // Указатель на предыдущий элемент
    Node* next;     // Указатель на следующий элемент
};

// Функция для добавления элемента в конец очереди
void enqueue(Node** front, Node** rear, int value) {
    Node* newNode = new Node();
    newNode->data = value;
    newNode->next = nullptr;
    
    if (*rear == nullptr) {
        // Если очередь пуста
        newNode->prev = nullptr;
        *front = *rear = newNode;
    } else {
        // Добавление в конец
        newNode->prev = *rear;
        (*rear)->next = newNode;
        *rear = newNode;
    }
}

// Функция для удаления указанного узла из очереди
void deleteNode(Node** front, Node** rear, Node* target) {
    if (*front == nullptr || target == nullptr) 
        return;

    // Обновление связей соседних узлов
    if (target->prev != nullptr) 
        target->prev->next = target->next;
    else 
        *front = target->next; // Удаление первого элемента

    if (target->next != nullptr) 
        target->next->prev = target->prev;
    else 
        *rear = target->prev; // Удаление последнего элемента

    delete target; // Освобождение памяти
}

// Функция для удаления всех нечетных элементов
void removeOdd(Node** front, Node** rear) {
    Node* current = *front;
    while (current != nullptr) {
        Node* nextNode = current->next; // Сохранение указателя на следующий узел
        if (current->data % 2 != 0) {   // Проверка на нечетность
            deleteNode(front, rear, current);
        }
        current = nextNode; // Переход к следующему узлу
    }
}

// Функция для освобождения памяти всей очереди
void freeQueue(Node** front, Node** rear) {
    Node* current = *front;
    while (current != nullptr) {
        Node* nextNode = current->next;
        delete current;
        current = nextNode;
    }
    *front = *rear = nullptr; // Обнуление указателей
}

// Функция для печати элементов очереди (для проверки)
void printQueue(Node* front) {
    Node* current = front;
    while (current != nullptr) {
        cout << current->data << " ";
        current = current->next;
    }
    cout << endl;
}

int main() {
    Node* front = nullptr; // Указатель на начало очереди
    Node* rear = nullptr;  // Указатель на конец очереди
    int num;

    cout << "Введите 9 целых чисел:" << endl;
    for (int i = 0; i < 9; i++) {
        cin >> num;
        enqueue(&front, &rear, num);
    }

    cout << "Исходная очередь: ";
    printQueue(front);

    removeOdd(&front, &rear);

    cout << "Очередь после удаления нечетных элементов: ";
    printQueue(front);

    freeQueue(&front, &rear); // Освобождение памяти

    return 0;
}
