
`timescale 1ns/1ps

module stride_predictor_tb;

    reg clk;
    reg rst;

    reg access_valid;
    reg [27:0] line_addr;

    wire prefetch_valid;
    wire [27:0] prefetch_line;

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Predictor instance
    stride_predictor dut (
        .clk(clk),
        .rst(rst),

        .access_valid(access_valid),
        .line_addr(line_addr),

        .prefetch_valid(prefetch_valid),
        .prefetch_line(prefetch_line)
    );

    // Send one cache-line access
    task send_access;
        input [27:0] address;

        begin
            @(negedge clk);
            line_addr = address;
            access_valid = 1'b1;

            @(posedge clk);
            #1;

            $display(
                "Accessed line = %h | Confidence = %0d | Prefetch valid = %b | Predicted line = %h",
                address,
                dut.confidence,
                prefetch_valid,
                prefetch_line
            );

            @(negedge clk);
            access_valid = 1'b0;
        end
    endtask

    initial begin

        rst = 1'b1;
        access_valid = 1'b0;
        line_addr = 28'b0;

        repeat (2) @(negedge clk);
        rst = 1'b0;

        $display("\n--- POSITIVE STRIDE TEST ---");

        send_access(28'h100);
        send_access(28'h101);
        send_access(28'h102);
        send_access(28'h103);
        send_access(28'h104);

        $display("\n--- NEGATIVE STRIDE TEST ---");

        send_access(28'h200);
        send_access(28'h1FF);
        send_access(28'h1FE);
        send_access(28'h1FD);

        #20;
        $finish;
    end

    initial begin
        $dumpfile("stride_predictor.vcd");
        $dumpvars(0, stride_predictor_tb);
    end

endmodule
