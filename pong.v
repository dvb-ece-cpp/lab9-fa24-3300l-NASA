
module pong(
    input clk,
    input btn_up,       // Button for moving paddle up
    input btn_down,     // Button for moving paddle down
    output vga_h_sync,
    output vga_v_sync,
    output vga_R,
    output vga_G,
    output vga_B
);

    wire inDisplayArea;
    wire [9:0] CounterX;
    wire [8:0] CounterY;

    // Instantiate the HV sync generator
    hvsync_generator syncgen(
        .clk(clk), 
        .vga_h_sync(vga_h_sync), 
        .vga_v_sync(vga_v_sync), 
        .inDisplayArea(inDisplayArea), 
        .CounterX(CounterX), 
        .CounterY(CounterY)
    );

    /////////////////////////////////////////////////////////////////
    reg [8:0] PaddlePosition;

    // Handle paddle movement using buttons
    always @(posedge clk) begin
        if (btn_up && ~&PaddlePosition)       // Move paddle up, prevent overflow
            PaddlePosition <= PaddlePosition + 1;
        else if (btn_down && |PaddlePosition) // Move paddle down, prevent underflow
            PaddlePosition <= PaddlePosition - 1;
    end

    /////////////////////////////////////////////////////////////////
    reg [9:0] ballX;
    reg [8:0] ballY;
    reg ball_inX, ball_inY;

    always @(posedge clk)
    if (ball_inX == 0) 
        ball_inX <= (CounterX == ballX) & ball_inY; 
    else 
        ball_inX <= !(CounterX == ballX + 16);

    always @(posedge clk)
    if (ball_inY == 0) 
        ball_inY <= (CounterY == ballY); 
    else 
        ball_inY <= !(CounterY == ballY + 16);

    wire ball = ball_inX & ball_inY;

    /////////////////////////////////////////////////////////////////
    wire border = (CounterX[9:3] == 0) || (CounterX[9:3] == 79) || (CounterY[8:3] == 0) || (CounterY[8:3] == 59);
    wire paddle = (CounterX >= PaddlePosition + 8) && (CounterX <= PaddlePosition + 120) && (CounterY[8:4] == 27);
    wire BouncingObject = border | paddle; // Active if the border or paddle is redrawing itself

    reg ResetCollision;
    always @(posedge clk) ResetCollision <= (CounterY == 500) & (CounterX == 0);  // Active only once for every video frame

    reg CollisionX1, CollisionX2, CollisionY1, CollisionY2;
    always @(posedge clk) if (ResetCollision) CollisionX1 <= 0; else if (BouncingObject & (CounterX == ballX) & (CounterY == ballY + 8)) CollisionX1 <= 1;
    always @(posedge clk) if (ResetCollision) CollisionX2 <= 0; else if (BouncingObject & (CounterX == ballX + 16) & (CounterY == ballY + 8)) CollisionX2 <= 1;
    always @(posedge clk) if (ResetCollision) CollisionY1 <= 0; else if (BouncingObject & (CounterX == ballX + 8) & (CounterY == ballY)) CollisionY1 <= 1;
    always @(posedge clk) if (ResetCollision) CollisionY2 <= 0; else if (BouncingObject & (CounterX == ballX + 8) & (CounterY == ballY + 16)) CollisionY2 <= 1;

    /////////////////////////////////////////////////////////////////
    wire UpdateBallPosition = ResetCollision;  // Update the ball position at the same time that we reset the collision detectors

    reg ball_dirX, ball_dirY;
    always @(posedge clk)
    if (UpdateBallPosition) begin
        if (~(CollisionX1 & CollisionX2))        // If collision on both X-sides, don't move in the X direction
        begin
            ballX <= ballX + (ball_dirX ? -1 : 1);
            if (CollisionX2) ball_dirX <= 1; else if (CollisionX1) ball_dirX <= 0;
        end

        if (~(CollisionY1 & CollisionY2))        // If collision on both Y-sides, don't move in the Y direction
        begin
            ballY <= ballY + (ball_dirY ? -1 : 1);
            if (CollisionY2) ball_dirY <= 1; else if (CollisionY1) ball_dirY <= 0;
        end
    end 

    /////////////////////////////////////////////////////////////////
    wire R = BouncingObject | ball | (CounterX[3] ^ CounterY[3]);
    wire G = BouncingObject | ball;
    wire B = BouncingObject | ball;

    reg vga_R, vga_G, vga_B;
    always @(posedge clk) begin
        vga_R <= R & inDisplayArea;
        vga_G <= G & inDisplayArea;
        vga_B <= B & inDisplayArea;
    end

endmodule
