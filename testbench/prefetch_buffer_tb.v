
module prefetch_buffer_tb;

    reg clk, rst;

    reg insert;
    reg [27:0] insert_line;
    reg [127:0] insert_data;

    reg lookup;
    reg [27:0] lookup_line;
    wire hit;
    wire [127:0] hit_data;

    reg consume;
    reg [27:0] consume_line;

    prefetch_buffer dut (
        .clk(clk),
        .rst(rst),
        .insert(insert),
        .insert_line(insert_line),
        .insert_data(insert_data),
        .lookup(lookup),
        .lookup_line(lookup_line),
        .hit(hit),
        .hit_data(hit_data),
        .consume(consume),
        .consume_line(consume_line)
    );

    always #5 clk = ~clk;

    task insert_entry;
        input [27:0] address;
        input [127:0] value;
        begin
            @(negedge clk);
            insert = 1;
            insert_line = address;
            insert_data = value;

            @(negedge clk);
            insert = 0;
        end
    endtask

    task lookup_entry;
        input [27:0] address;
        begin
            @(negedge clk);
            lookup = 1;
            lookup_line = address;

            @(posedge clk);
            #1;
            if (hit)
                $display("HIT: line=%h data=%h",
                         address, hit_data);
            else
                $display("MISS: line=%h", address);

            @(negedge clk);
            lookup = 0;
        end
    endtask

    task consume_entry;
        input [27:0] address;
        begin
            @(negedge clk);
            consume = 1;
            consume_line = address;

            @(negedge clk);
            consume = 0;
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        insert = 0;
        lookup = 0;
        consume = 0;
        insert_line = 0;
        insert_data = 0;
        lookup_line = 0;
        consume_line = 0;

        repeat (2) @(negedge clk);
        rst = 0;

        $display("\n--- INSERT FOUR ENTRIES ---");

        insert_entry(28'h100, 128'hAAAA);
        insert_entry(28'h101, 128'hBBBB);
        insert_entry(28'h102, 128'hCCCC);
        insert_entry(28'h103, 128'hDDDD);

        $display("\n--- LOOKUP TESTS ---");

        lookup_entry(28'h100);
        lookup_entry(28'h102);
        lookup_entry(28'h105);

        $display("\n--- CONSUME TEST ---");

        consume_entry(28'h102);
        lookup_entry(28'h102);

        $display("\n--- ROUND-ROBIN REPLACEMENT TEST ---");

        insert_entry(28'h104, 128'hEEEE);
        lookup_entry(28'h100);
        lookup_entry(28'h104);

        $display("\n--- TEST COMPLETE ---");
        $finish;
    end

endmodule
