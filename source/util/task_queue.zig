/////////////////////////////////////////////////////////////////////////////////
// Copyright 2024 Edward Pizzella
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,          
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
/////////////////////////////////////////////////////////////////////////////////

const Task = @import("../os_task.zig").Task;
const Self = @This();

pub const TaskHandle = struct {
    _data: Task,
    _to_tail: ?*TaskHandle = null,
    _to_head: ?*TaskHandle = null,
    name: []const u8,
};

head: ?*TaskHandle = null,
tail: ?*TaskHandle = null,
elements: u32 = 0,

///Insert `insert_node` before `target_node`.  When `target_node` is null prepend to head
pub fn insertBefore(self: *Self, insert_node: *TaskHandle, target_node: ?*TaskHandle) void {
    if (target_node) |t_node| {
        //insert before
        insert_node._to_head = t_node._to_head;
        insert_node._to_tail = t_node;
        t_node._to_head = insert_node;
        if (target_node == self.head) self.head = insert_node;
        if (insert_node._to_head) |insert_head| insert_head._to_tail = insert_node;
    } else {
        //prepend to head.
        if (self.head) |head| {
            insert_node._to_tail = head;
            head._to_head = insert_node;
            insert_node._to_head = null; //this should already be null.
        } else {
            self.tail = insert_node;
        }
        self.head = insert_node;
    }

    self.elements += 1;
}

///Insert `insert_node` after `target_node`.  When `target_node` is null append to head
pub fn insertAfter(self: *Self, insert_node: *TaskHandle, target_node: ?*TaskHandle) void {
    if (target_node) |t_node| {
        //insert after
        insert_node._to_tail = t_node._to_tail;
        insert_node._to_head = t_node;
        t_node._to_tail = insert_node;
        if (t_node == self.tail) self.tail = insert_node;
        if (insert_node._to_tail) |insert_tail| insert_tail._to_head = insert_node;
    } else {
        //append to tail.
        if (self.tail) |tail| {
            insert_node._to_head = tail;
            tail._to_tail = insert_node;
            insert_node._to_tail = null; //this should already be null.
        } else {
            self.head = insert_node;
        }
        self.tail = insert_node;
    }

    self.elements += 1;
}

//Insert a task into the queue based on its priority
pub fn insertSorted(self: *Self, insert_node: *TaskHandle) void {
    var search: ?*TaskHandle = self.tail;
    while (true) {
        if (search) |s| {
            if (insert_node._data.priority >= s._data.priority) {
                self.insertAfter(insert_node, s);
                break;
            } else {
                search = s._to_head;
            }
        } else {
            self.insertBefore(insert_node, search);
            break;
        }
    }
}

///Pop the head node from the queue
pub fn pop(self: *Self) ?*TaskHandle {
    const rtn = self.head orelse return null;
    self.head = rtn._to_tail;
    rtn._to_tail = null;
    self.elements -= 1;
    if (self.head) |new_head| {
        new_head._to_head = null;
    } else {
        self.tail = null;
    }
    return rtn;
}

///Returns true if the specified node is contained in the queue
pub fn contains(self: *Self, node: *TaskHandle) bool {
    var rtn = false;
    if (self.head) |head| {
        var current_node: *TaskHandle = head;
        while (true) {
            if (current_node == node) {
                rtn = true;
                break;
            }
            if (current_node._to_tail) |next| {
                current_node = next;
            } else {
                break;
            }
        }
    }

    return rtn;
}

///Removes the specified task from the queue.  Returns false if the node is not contained in the queue.
pub fn remove(self: *Self, node: *TaskHandle) bool {
    var rtn = false;

    if (self.contains(node)) {
        if (self.head == self.tail) { //list of 1
            self.head = null;
            self.tail = null;
        } else if (self.head == node) {
            if (node._to_tail) |towardTail| {
                self.head = towardTail;
                towardTail._to_head = null;
            }
        } else if (self.tail == node) {
            if (node._to_head) |towardHead| {
                self.tail = towardHead;
                towardHead._to_tail = null;
            }
        } else {
            if (node._to_head) |towardHead| {
                towardHead._to_tail = node._to_tail;
            }
            if (node._to_tail) |towardTail| {
                towardTail._to_head = node._to_head;
            }
        }

        node._to_head = null;
        node._to_tail = null;

        self.elements -= 1;
        rtn = true;
    }

    return rtn;
}

///Move the head task to the tail position
pub fn headToTail(self: *Self) void {
    if (self.head != self.tail) {
        if (self.head != null and self.tail != null) {
            const temp = self.head;
            self.head.?._to_tail.?._to_head = null;
            self.head = self.head.?._to_tail;

            temp.?._to_tail = null;
            self.tail.?._to_tail = temp;
            temp.?._to_head = self.tail;
            self.tail = temp;
        }
    }
}
