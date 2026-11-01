
`timescale 1ns/1ps

module tb_dram;

    reg clk;
    reg rst;

    reg req;
    reg [31:0] addr;

    wire busy;
    wire rsp_valid;
    wire [127:0] rsp_data;

    dram_model #(
        .LATENCY(20)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .req(req),
        .addr(addr),
        .busy(busy),
        .rsp_valid(rsp_valid),
        .rsp_data(rsp_data)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    initial begin

        $dumpfile("dram.vcd");
        $dumpvars(0, tb_dram);

        clk = 0;
        rst = 1;
        req = 0;
        addr = 0;

        // Reset
        repeat(2) @(negedge clk);
        rst = 0;

        // Request cache line at address 0
        @(negedge clk);
        addr = 32'h00000000;
        req = 1;

        @(negedge clk);
        req = 0;

        // Wait for response
        wait(rsp_valid == 1);

        $display("--------------------------------");
        $display("DRAM RESPONSE RECEIVED");
        $display("Address : %h", addr);
        $display("Data    : %h", rsp_data);
        $display("--------------------------------");

        // Second cache-line request
        @(negedge clk);
        addr = 32'h00000010;
        req = 1;

        @(negedge clk);
        req = 0;

        wait(rsp_valid == 1);

        $display("SECOND RESPONSE");
        $display("Data : %h", rsp_data);

        #20;
        $finish;

    end

endmodule
