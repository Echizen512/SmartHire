// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol"; //Contract AccessControl by OpenZeppelin

contract TaskContract is AccessControl {
    //roles
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    uint256 public taskID = 0;
    uint256 auditorID = 0;
    uint256 userID = 0;
    uint256 taskCompletedID = 0;
    address public admin;

    struct Task {
        uint256 taskID;
        string name;
        string description;
        string rules;
        uint256 reward;
        address payable responsible;
        bool completed;
    }

    struct Auditor {
        uint256 auditorID;
        address auditorAddress;
        bool block;
    }

    struct TaskCompleted {
        uint256 taskCompletedID;
        uint256 taskID;
        string proof;
        address verifier;
        bool verified;
    }

    //mappings
    mapping(uint256 => Task) public tasks;
    mapping(uint256 => Auditor) public auditors;
    mapping(uint256 => address) public users;
    mapping(uint256 => TaskCompleted) tasksCompleted;

    //events
    event AuditorAdded(address indexed auditor);
    event TaskAdded(uint256 indexed taskID, string name);
    event UserAdded(address indexed userAddress);

    //constructor
    constructor(address _admin) {
        admin = _admin;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    //functions
    function addUser(address _addressUser) public {
        require(_addressUser != address(0), "User address cannot be zero address");
        require(admin != _addressUser, "Admin cannot be user");
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(AUDITOR_ROLE, msg.sender),
            "Caller is not an admin or auditor"
        );

        require(!getUserForAddress(_addressUser), "User already exists");
        require(!getAuditorForAddress(_addressUser), "Adress is auditor");

        _grantRole(USER_ROLE, _addressUser);
        users[userID] = _addressUser;
        userID++;
        emit UserAdded(_addressUser);
    }

    function getAllUsers() public view returns (address[] memory) {
        address[] memory userList = new address[](userID);
        for (uint256 i = 0; i < userID; i++) {
            userList[i] = users[i];
        }
        return userList;
    }

    function getUserForAddress(address _addressUser) public view returns (bool) {
        require(_addressUser != address(0), "User address cannot be zero address");

        for (uint256 i = 0; i < userID; i++) {
            if (users[i] == _addressUser) return true;
        }

        return false;
    }

    function createTask(
        string memory _name,
        string memory _description,
        string memory _rules
    ) public payable onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(_name).length > 0, "Task name cannot be empty");
        require(bytes(_description).length > 0, "Task description cannot be empty");
        require(bytes(_rules).length > 0, "Task rules cannot be empty");
        require(msg.value > 0, "A reward must be provided");

        tasks[taskID] = Task(taskID, _name, _description, _rules, msg.value, payable(address(0)), false);

        taskID++;
        emit TaskAdded(taskID, _name);
    }

    function createTaskWithResponsible(
        string memory _name,
        string memory _description,
        string memory _rules,
        address _responsible
    ) public payable onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bytes(_name).length > 0, "Task name cannot be empty");
        require(bytes(_description).length > 0, "Task description cannot be empty");
        require(bytes(_rules).length > 0, "Task rules cannot be empty");

        require(msg.value > 0, "A reward must be provided");
        require(admin != _responsible, "Address is admin");
        require(!getAuditorForAddress(_responsible), "Adress is auditor");

        tasks[taskID] = Task(taskID, _name, _description, _rules, msg.value, payable(_responsible), false);

        if (!getUserForAddress(_responsible)) {
            _grantRole(USER_ROLE, _responsible);
            users[userID] = _responsible;
            userID++;
            emit UserAdded(_responsible);
        }

        taskID++;
        emit TaskAdded(taskID, _name);
    }

    function getTask(uint256 _taskID) public view returns (string memory, string memory) {
        Task storage task = tasks[_taskID];
        return (task.name, task.description);
    }

    function getAllTasks() public view returns (Task[] memory) {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(AUDITOR_ROLE, msg.sender),
            "Caller is not an admin or auditor"
        );
        Task[] memory taskList = new Task[](taskID);
        for (uint256 i = 0; i < taskID; i++) {
            Task storage task = tasks[i];
            taskList[i] = task;
        }
        return taskList;
    }

    function getTasksByResponsible() public view onlyRole(USER_ROLE) returns (Task[] memory) {
        require(msg.sender != address(0), "Sender address is required");
        uint256 count = 0;
        for (uint256 i = 0; i < taskID; i++) if (tasks[i].responsible == msg.sender) count++;

        Task[] memory result = new Task[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < taskID; i++) {
            if (tasks[i].responsible == msg.sender) {
                result[index] = tasks[i];
                index++;
            }
        }
        return result;
    }

    function getTasksWithoutResponsible() public view returns (Task[] memory) {
        uint256 count = 0;
        uint256 index = 0;

        for (uint256 i = 0; i < taskID; i++) {
            if (tasks[i].responsible == address(0)) count++;
        }

        Task[] memory tasksWithoutResponsible = new Task[](count);

        for (uint256 i = 0; i < taskID; i++) {
            if (tasks[i].responsible == address(0)) {
                tasksWithoutResponsible[index] = tasks[i];
                index++;
            }
        }

        return tasksWithoutResponsible;
    }

    function getCompletedTask(uint256 _taskID) public view returns (TaskCompleted memory) {
        for (uint256 i = 0; i < taskCompletedID; i++) {
            if (tasksCompleted[i].taskID == _taskID) {
                return tasksCompleted[i];
            }
        }
        return TaskCompleted(taskCompletedID, 0, "", address(0), false);
    }

    function acceptTask(uint256 _taskID) public {
        require(msg.sender != admin, "Address is admin");
        require(bytes(tasks[_taskID].name).length > 0, "The task does not exist");
        require(tasks[_taskID].responsible == address(0), "Task must have a responsible assigned");
        require(!getAuditorForAddress(msg.sender), "The auditor cannot take on tasks");

        if (!getUserForAddress(msg.sender)) {
            _grantRole(USER_ROLE, msg.sender);
            users[userID] = msg.sender;
            userID++;
            emit UserAdded(msg.sender);
        }
        tasks[_taskID].responsible = payable(msg.sender);
    }

    function completedTask(uint256 _taskID, string memory _proof) public onlyRole(USER_ROLE) {
        require(bytes(tasks[_taskID].name).length > 0, "The task does not exist");
        require(bytes(_proof).length > 0, "Proof cannot be empty");

        bool alreadyCompleted = false;
        for (uint256 i = 0; i < taskCompletedID; i++) {
            if (tasksCompleted[i].taskID == _taskID) {
                require(bytes(tasksCompleted[i].proof).length == 0, "The task has already been completed with proof");
                alreadyCompleted = true;
                break;
            }
        }
        if (!alreadyCompleted) {
            tasksCompleted[taskCompletedID] = TaskCompleted(taskCompletedID, _taskID, _proof, address(0), false);
            taskCompletedID++;
        }
    }

    function verifiedTask(uint256 _taskCompletedID, bool _verified) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(AUDITOR_ROLE, msg.sender),
            "Caller is not an admin or auditor"
        );

        string memory _proof = tasksCompleted[_taskCompletedID].proof;
        require(bytes(_proof).length > 0, "Proof cannot be empty");

        uint256 _taskID = tasksCompleted[_taskCompletedID].taskID;

        require(bytes(tasks[_taskID].name).length > 0, "The task does not exist");
        require(tasks[_taskID].responsible != payable(address(0)), "No responsible assigned");
        if (_verified) {
            tasksCompleted[_taskCompletedID].verifier = msg.sender;
            tasksCompleted[_taskCompletedID].verified = _verified;

            uint256 _amount = tasks[_taskID].reward;
            address _responsible = tasks[_taskID].responsible;
            tasks[_taskID].completed = true;

            (bool success, ) = payable(_responsible).call{ value: _amount }("");
            require(success);
        } else {
            //releases the task so that it can be accepted by another user
            tasksCompleted[_taskCompletedID].proof = "";
            tasksCompleted[_taskCompletedID].verifier = msg.sender;
            tasksCompleted[_taskCompletedID].verified = _verified;

            tasks[_taskID].responsible = payable(address(0));
        }
    }

    function addAuditor(address _auditorAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_auditorAddress != address(0), "Auditor address cannot be zero address");
        require(admin != _auditorAddress, "Admin cannot be auditor");
        require(!getAuditorForAddress(_auditorAddress), "Auditor already exist");
        require(!getUserForAddress(_auditorAddress), "User already exists");

        auditors[auditorID] = Auditor(auditorID, _auditorAddress, false);
        _grantRole(AUDITOR_ROLE, _auditorAddress);
        auditorID++;

        emit AuditorAdded(_auditorAddress);
    }

    function getAllAuditors() public view returns (Auditor[] memory) {
        Auditor[] memory auditorList = new Auditor[](auditorID);
        for (uint256 i = 0; i < auditorID; i++) {
            Auditor storage auditor = auditors[i];
            auditorList[i] = auditor;
        }
        return auditorList;
    }

    function getAuditorForAddress(address _auditorAddress) public view returns (bool) {
        for (uint256 i = 0; i <= auditorID; i++) {
            if (auditors[i].auditorAddress == _auditorAddress) return true;
        }
        return false;
    }

    function blockAuditor(uint256 _auditorID) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(auditors[_auditorID].auditorAddress != address(0), "Auditor does not exist");
        auditors[_auditorID].block = true;
        _revokeRole(AUDITOR_ROLE, auditors[_auditorID].auditorAddress);
    }

    function unlockAuditor(uint256 _auditorID) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(auditors[_auditorID].auditorAddress != address(0), "Auditor does not exist");
        auditors[_auditorID].block = false;
        _grantRole(AUDITOR_ROLE, auditors[_auditorID].auditorAddress);
    }
}
