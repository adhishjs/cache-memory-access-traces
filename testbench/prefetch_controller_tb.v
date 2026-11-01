
module prefetch_controller_tb;

    reg clk, rst;

    reg prefetch_valid;
    reg [27:0] prefetch_line;

    wire check_cache;
    wire [27:0] check_cache_line;
    reg cache_present;

    wire check_buffer;
    wire [27:0] check_buffer_line;
    reg buffer_present;

    wire prefetch_req;
    wire [31:0] prefetch_addr;
    reg prefetch_accept;
    reg prefetch_resp_valid;
    reg [127:0] prefetch_resp_data;

    wire buffer_insert;
    wire [27:0] buffer_insert_line;
    wire [127:0] buffer_insert_data;

    wire prefetch_done;
    wire [31:0] duplicate_count;
    wire [31:0] issued_count;

    prefetch_controller dut (
        .clk(clk),
        .rst(rst),

        .prefetch_valid(prefetch_valid),
        .prefetch_line(prefetch_line),

        .check_cache(check_cache),
        .check_cache_line(check_cache_line),
        .cache_present(cache_present),

        .check_buffer(check_buffer),
        .check_buffer_line(check_buffer_line),
        .buffer_present(buffer_present),

        .prefetch_req(prefetch_req),
        .prefetch_addr(prefetch_addr),
        .prefetch_accept(prefetch_accept),
        .prefetch_resp_valid(prefetch_resp_valid),
        .prefetch_resp_data(prefetch_resp_data),

        .buffer_insert(buffer_insert),
        .buffer_insert_line(buffer_insert_line),
        .buffer_insert_data(buffer_insert_data),

        .prefetch_done(prefetch_done),
        .duplicate_count(duplicate_count),
        .issued_count(issued_count)
    );

    always #5 clk = ~clk;

    // Simulate a prediction
    task send_prediction;
        input [27:0] line;
        begin
            @(negedge clk);
            prefetch_line = line;
            prefetch_valid = 1;

            @(negedge clk);
            prefetch_valid = 0;
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;

        prefetch_valid = 0;
        prefetch_line = 0;

        cache_present = 0;
        buffer_present = 0;

        prefetch_accept = 0;
        prefetch_resp_valid = 0;
        prefetch_resp_data = 0;

        repeat (2) @(negedge clk);
        rst = 0;

        // TEST 1: New prediction
        $display("\n--- TEST 1: NEW PREDICTION ---");

        send_prediction(28'h100);

        wait(prefetch_req);
        #1;

        $display("Prefetch request address = %h",
                 prefetch_addr);

        if (prefetch_addr !== 32'h00001000)
            $display("ERROR: Incorrect prefetch address");
        else
            $display("PASS: Correct address");

        // TEST 2: Hold request until accepted
        $display("\n--- TEST 2: REQUEST HANDSHAKE ---");

        repeat (3) begin
            @(negedge clk);
            if (!prefetch_req)
                $display("ERROR: Request was not held");
        end

        $display("Request remained asserted");

        @(negedge clk);
        prefetch_accept = 1;

        @(negedge clk);
        prefetch_accept = 0;

        if (prefetch_req)
            $display("ERROR: Request still asserted");
        else
            $display("PASS: Request cleared after acceptance");

        // TEST 3: DRAM response and buffer insertion
        $display("\n--- TEST 3: DRAM RESPONSE ---");

        @(negedge clk);
        prefetch_resp_data =
            128'hAAAA_BBBB_CCCC_DDDD_1111_2222_3333_4444;
        prefetch_resp_valid = 1;

        @(negedge clk);
        prefetch_resp_valid = 0;

        wait(buffer_insert);
        #1;

        $display("Inserted line = %h", buffer_insert_line);
        $display("Inserted data = %h", buffer_insert_data);

        if (buffer_insert_line !== 28'h100)
            $display("ERROR: Incorrect inserted line");
        else if (buffer_insert_data !==
                 128'hAAAA_BBBB_CCCC_DDDD_1111_2222_3333_4444)
            $display("ERROR: Incorrect inserted data");
        else
            $display("PASS: Buffer insertion data correct");

        // TEST 4: Duplicate prediction
        $display("\n--- TEST 4: DUPLICATE SUPPRESSION ---");

        @(negedge clk);
        cache_present = 1;

        send_prediction(28'h100);

        wait(prefetch_done);
        #1;

        if (prefetch_req)
            $display("ERROR: Duplicate generated request");
        else
            $display("PASS: Duplicate request suppressed");

        $display("Duplicate count = %0d", duplicate_count);
        $display("Issued count = %0d", issued_count);

        $display("\n--- TEST COMPLETE ---");

        #20;
        $finish;
    end

endmodule
