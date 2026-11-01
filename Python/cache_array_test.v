
module cache_array_test;

    reg [127:0] data_mem [0:63];
    reg [21:0]  tag_mem [0:63];
    reg         valid_mem [0:63];

    integer i;

    initial begin

        // Initialize all valid bits
        for (i = 0; i < 64; i = i + 1) begin
            valid_mem[i] = 1'b0;
            tag_mem[i]   = 22'b0;
            data_mem[i]  = 128'b0;
        end

        // Store one cache line at index 5
        data_mem[5] = 128'h44444444_33333333_22222222_11111111;
        tag_mem[5]  = 22'h000123;
        valid_mem[5] = 1'b1;

        // Display stored values
        $display("Data  = %h", data_mem[5]);
        $display("Tag   = %h", tag_mem[5]);
        $display("Valid = %b", valid_mem[5]);

        // Read individual 32-bit words
        $display("Word 0 = %h", data_mem[5][31:0]);
        $display("Word 1 = %h", data_mem[5][63:32]);
        $display("Word 2 = %h", data_mem[5][95:64]);
        $display("Word 3 = %h", data_mem[5][127:96]);

        $finish;
    end

endmodule

