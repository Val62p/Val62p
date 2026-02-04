const board = document.getElementById("board");
const statusText = document.getElementById("status-text");
const turnText = document.getElementById("turn-text");
const startButton = document.getElementById("start");
const restartButton = document.getElementById("restart");
const audioToggle = document.getElementById("audio-toggle");
const stepsAudio = document.getElementById("audio-steps");
const dangerAudio = document.getElementById("audio-danger");

const size = 7;
const cells = [];

let player = { x: 0, y: 0 };
let monster = { x: 6, y: 6 };
let key = { x: 3, y: 1 };
let door = { x: 6, y: 0 };
let hasKey = false;
let moves = 0;
let isGameOver = false;
let isStarted = false;

const directions = {
  up: { x: 0, y: -1 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
};

function buildBoard() {
  board.innerHTML = "";
  cells.length = 0;
  for (let row = 0; row < size; row += 1) {
    for (let col = 0; col < size; col += 1) {
      const cell = document.createElement("div");
      const content = document.createElement("div");
      cell.className = "cell";
      content.className = "cell__content";
      cell.appendChild(content);
      board.appendChild(cell);
      cells.push(cell);
    }
  }
}

function cellIndex(position) {
  return position.y * size + position.x;
}

function clampPosition(position) {
  return {
    x: Math.max(0, Math.min(size - 1, position.x)),
    y: Math.max(0, Math.min(size - 1, position.y)),
  };
}

function updateBoard() {
  cells.forEach((cell) => {
    cell.className = "cell";
  });

  cells[cellIndex(door)].classList.add("door");
  if (!hasKey) {
    cells[cellIndex(key)].classList.add("key");
  }
  cells[cellIndex(monster)].classList.add("monster");
  cells[cellIndex(player)].classList.add("player");

  turnText.textContent = `Tours ${moves}`;
}

function setStatus(message) {
  statusText.textContent = message;
}

function playSound(audioElement) {
  if (!audioToggle.checked) {
    return;
  }
  audioElement.currentTime = 0;
  audioElement.play().catch(() => {});
}

function moveMonster() {
  const options = [];
  if (monster.x < player.x) {
    options.push({ x: monster.x + 1, y: monster.y });
  } else if (monster.x > player.x) {
    options.push({ x: monster.x - 1, y: monster.y });
  }
  if (monster.y < player.y) {
    options.push({ x: monster.x, y: monster.y + 1 });
  } else if (monster.y > player.y) {
    options.push({ x: monster.x, y: monster.y - 1 });
  }
  if (options.length === 0) {
    return;
  }
  const choice = options[Math.floor(Math.random() * options.length)];
  monster = clampPosition(choice);
}

function checkState() {
  if (player.x === monster.x && player.y === monster.y) {
    setStatus("Le monstre vous a attrapé. Recommencez.");
    isGameOver = true;
    playSound(dangerAudio);
    return;
  }

  if (!hasKey && player.x === key.x && player.y === key.y) {
    hasKey = true;
    setStatus("Clé trouvée ! Courez vers la porte.");
  }

  if (hasKey && player.x === door.x && player.y === door.y) {
    setStatus("Vous avez fui. Victoire !");
    isGameOver = true;
  }
}

function movePlayer(direction) {
  if (!isStarted || isGameOver) {
    return;
  }
  const delta = directions[direction];
  if (!delta) {
    return;
  }
  const next = clampPosition({ x: player.x + delta.x, y: player.y + delta.y });
  if (next.x === player.x && next.y === player.y) {
    return;
  }
  player = next;
  moves += 1;
  playSound(stepsAudio);
  checkState();
  if (!isGameOver) {
    moveMonster();
    checkState();
  }
  updateBoard();
}

function resetGame() {
  player = { x: 0, y: 0 };
  monster = { x: 6, y: 6 };
  key = { x: 3, y: 1 };
  door = { x: 6, y: 0 };
  hasKey = false;
  moves = 0;
  isGameOver = false;
  isStarted = false;
  setStatus("Appuyez sur Démarrer.");
  updateBoard();
}

function startGame() {
  if (isStarted) {
    return;
  }
  isStarted = true;
  setStatus("Trouvez la clé.");
}

buildBoard();
resetGame();

startButton.addEventListener("click", startGame);
restartButton.addEventListener("click", resetGame);

document.addEventListener("keydown", (event) => {
  const keyMap = {
    ArrowUp: "up",
    ArrowDown: "down",
    ArrowLeft: "left",
    ArrowRight: "right",
    w: "up",
    a: "left",
    s: "down",
    d: "right",
    z: "up",
    q: "left",
  };
  const direction = keyMap[event.key];
  if (direction) {
    movePlayer(direction);
  }
});
