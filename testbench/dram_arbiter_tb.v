
module dram_arbiter_tb;

    reg clk, rst;

    reg demand_req;
    reg [31:0] demand_addr;
    wire demand_accept;
    wire demand_resp_valid;
    wire [127:0] demand_resp_data;

    reg prefetch_req;
    reg [31:0] prefetch_addr;
    wire prefetch_accept;
    wire prefetch_resp_valid;
    wire [127:0] prefetch_resp_data;

    wire dram_req;
    wire [31:0] dram_addr;
    wire dram_busy;
    wire dram_resp_valid;
    wire [127:0] dram_resp_data;

    dram_arbiter dut (
        .clk(clk),
        .rst(rst),

        .demand_req(demand_req),
        .demand_addr(demand_addr),
        .demand_accept(demand_accept),
        .demand_resp_valid(demand_resp_valid),
        .demand_resp_data(demand_resp_data),

        .prefetch_req(prefetch_req),
        .prefetch_addr(prefetch_addr),
        .prefetch_accept(prefetch_accept),
        .prefetch_resp_valid(prefetch_resp_valid),
        .prefetch_resp_data(prefetch_resp_data),

        .dram_req(dram_req),
        .dram_addr(dram_addr),
        .dram_busy(dram_busy),
        .dram_resp_valid(dram_resp_valid),
        .dram_resp_data(dram_resp_data)
    );

    dram_model #(
        .LATENCY(5),
        .MEM_WORDS(16384)
    ) dram (
        .clk(clk),
        .rst(rst),
        .dram_req(dram_req),
        .dram_addr(dram_addr),
        .dram_busy(dram_busy),
        .resp_valid(dram_resp_valid),
        .resp_data(dram_resp_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;

        demand_req = 0;
        demand_addr = 0;

        prefetch_req = 0;
        prefetch_addr = 0;

        repeat (2) @(negedge clk);
        rst = 0;

        // Test 1: Demand alone
        $display("\n--- TEST 1: DEMAND ONLY ---");

        @(negedge clk);
        demand_req = 1;
        demand_addr = 32'h00001000;

        wait(demand_accept);
        @(negedge clk);
        demand_req = 0;

        wait(demand_resp_valid);
        $display("Demand response: %h", demand_resp_data);

        // Test 2: Prefetch alone
        $display("\n--- TEST 2: PREFETCH ONLY ---");

        @(negedge clk);
        prefetch_req = 1;
        prefetch_addr = 32'h00001010;

        wait(prefetch_accept);
        @(negedge clk);
        prefetch_req = 0;

        wait(prefetch_resp_valid);
        $display("Prefetch response: %h", prefetch_resp_data);

        // Test 3: Both requests together
        $display("\n--- TEST 3: BOTH REQUESTS ---");

        @(negedge clk);
        demand_req = 1;
        demand_addr = 32'h00002000;

        prefetch_req = 1;
        prefetch_addr = 32'h00002010;

        wait(demand_accept);
        $display("Demand accepted first");

        @(negedge clk);
        demand_req = 0;

        wait(demand_resp_valid);
        $display("Demand response: %h", demand_resp_data);

        // Prefetch should now be accepted
        wait(prefetch_accept);
        $display("Prefetch accepted second");

        @(negedge clk);
        prefetch_req = 0;

        wait(prefetch_resp_valid);
        $display("Prefetch response: %h", prefetch_resp_data);

        $display("\n--- ALL TESTS COMPLETE ---");
        #10;
        $finish;
    end

endmodule
