
window.onload=function(){
var animate = window.requestAnimationFrame || window.webkitRequestAnimationFrame || window.mozRequestAnimationFrame || function (callback) {

    window.setTimeout(callback, 1000 / 60)
};

var canvas = document.createElement("canvas");
var width = 700;
var height = 500;
canvas.width = width;
canvas.height = height;
var context = canvas.getContext('2d');
var player = new Player();
var computer = new Computer();
var ball = new Ball(width/2, height/2);
var pause = false;

var keysDown = {};

var render = function () {
//    context.fillStyle = "#FF00FF";
    context.fillStyle = "#000";
    context.fillRect(0, 0, width, height);
    player.render();
    computer.render();
    ball.render();
};

document.updateState = function(state) {
	// update paddles
	// for(var i = 1; i < paddles.length; i++) {
	// 	p = paddles[i];
	// 	console.log("paddle "+i+": "+state.paddles["p"+i].x)
	// 	p.x = state.paddles["p"+i].x - p.w/2;
	// }

	// update ball
	ball.x = state.ball.x;
	ball.y = state.ball.y;
}

var update = function () {
    // player.update();
    // computer.update(ball);
    // ball.update(player.paddle, computer.paddle);
};

var step = function () {

    var reset = false;
    for (var key in keysDown) {
        var value = Number(key);
        if (value == 19) {
            pause = !pause;
            reset = true;
            break;
        }
    }
    if (reset) {
        keysDown = {};
        reset = false;
    }
    // console.log("P: " + pause);

    if (!pause) {
        update();
        render();
    }
    animate(step);
};

function Paddle(x, y, width, height) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.x_speed = 0;
    this.y_speed = 0;
}

Paddle.prototype.render = function () {
    context.fillStyle = "#00CC00";
    context.fillRect(this.x, this.y, this.width, this.height);
};

Paddle.prototype.move = function (x, y) {
    this.x += x;
    this.y += y;
    this.x_speed = x;
    this.y_speed = y;
    if (this.x < 0) {
        this.x = 0;
        this.x_speed = 0;
    } else if (this.x + this.width > width) {
        this.x = width - this.width;
        this.x_speed = 0;
    }
};

function Computer() {
    this.paddle = new Paddle(width-50, height/2, 10, 50);
}

Computer.prototype.render = function () {
    this.paddle.render();
};

Computer.prototype.update = function (ball) {
    var y_pos = ball.y;
    var diff = -((this.paddle.y + (this.paddle.height / 2)) - y_pos);
    if (diff < 0 && diff < -4) {
        diff = -5;
    } else if (diff > 0 && diff > 4) {
        diff = 5;
    }
    this.paddle.move(0, diff);
    if (this.paddle.y < 0) {
        this.paddle.y = 0;
    } else if (this.paddle.y + this.paddle.height > height) {
        this.paddle.y = height - this.paddle.height;
    }
};

function Player() {
    this.paddle = new Paddle(50, height/2, 10, 50);
}

Player.prototype.render = function () {
    this.paddle.render();
};

Player.prototype.update = function () {
    for (var key in keysDown) {
        var value = Number(key);
        /*
        if (value == 37) {
            this.paddle.move(0, 0);
        } else if (value == 39) {
            this.paddle.move(4, 0);
        } else {
            this.paddle.move(0, 0);
        }
        */
        if (value == 38) {
            this.paddle.move(0, -4);
        } else if (value == 40) {
            this.paddle.move(0, 4);
        } else {
            this.paddle.move(0, 0);
        }
    }
};

function Ball(x, y) {
    this.x = x;
    this.y = y;
    this.x_speed = -3;
    this.y_speed = 0;
}

Ball.prototype.render = function () {
    context.beginPath();
    context.arc(this.x, this.y, 5, 2 * Math.PI, false);
//    context.fillStyle = "#000000";
    context.fillStyle = "#fff";
    context.fill();
};

Ball.prototype.update = function (paddle1, paddle2) {
    this.x += this.x_speed;
    this.y += this.y_speed;
    var top_x = this.x - 5;
    var top_y = this.y - 5;
    var bottom_x = this.x + 5;
    var bottom_y = this.y + 5;

/*
    if (this.x - 5 < 0) {
        this.x = 5;
        this.x_speed = -this.x_speed;
    } else if (this.x + 5 > width) {
        this.x = width - 5;
        this.x_speed = -this.x_speed;
    }

    if (this.y < 0 || this.y > height) {
        this.x_speed = -3;
        this.y_speed = 0;
        this.x = width/2;
        this.y = height/2;
    }
    */

    // wandkollision
    if (this.y - 5 < 0) {
        this.y = 5;
        this.y_speed = -this.y_speed;
    } else if (this.y + 5 > height) {
        this.y = height - 5;
        this.y_speed = -this.y_speed;
    }

    if (this.x < 0 || this.x > width) { // goal --> reset
        this.x_speed = -3;
        this.y_speed = 0;
        this.x = width/2;
        this.y = height/2;
    }

    if (top_x < (width/2)) {
        /*
        if (top_y < (paddle1.y + paddle1.height) && bottom_y > paddle1.y && top_x < (paddle1.x + paddle1.width) && bottom_x > paddle1.x) {
            this.y_speed = -3;
            this.x_speed += (paddle1.x_speed / 2);
            this.y += this.y_speed;
        }
        */
        if (top_y < (paddle1.y + paddle1.height) && bottom_y > paddle1.y && top_x < (paddle1.x + paddle1.width) && bottom_x > paddle1.x) {
            this.x_speed = 3;
            this.y_speed += (paddle1.y_speed / 2);
            this.x += this.x_speed;
        }
    } else {

        if (top_y < (paddle2.y + paddle2.height) && bottom_y > paddle2.y && top_x < (paddle2.x + paddle2.width) && bottom_x > paddle2.x) {
            this.x_speed = -3;
            this.y_speed += (paddle2.y_speed / 2);
            this.x += this.x_speed;
        }

    }
};

document.body.appendChild(canvas);
animate(step);

window.addEventListener("keydown", function (event) {
    keysDown[event.keyCode] = true;
});

window.addEventListener("keyup", function (event) {
    delete keysDown[event.keyCode];
});

}
