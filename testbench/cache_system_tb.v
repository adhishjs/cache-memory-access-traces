
module cache_system_tb;

    reg clk;
    reg rst;

    reg cpu_req;
    reg [31:0] cpu_addr;

    wire [31:0] cpu_rdata;
    wire cpu_ready;

    integer i;
    integer total_dram_requests;
    integer total_prefetch_requests;
    integer total_prefetch_hits;
    integer total_cache_hits;
    integer total_cache_misses;
    cache_system dut (
        .clk(clk),
        .rst(rst),

        .cpu_req(cpu_req),
        .cpu_addr(cpu_addr),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready)
    );

    always #5 clk = ~clk;

    // CPU read task
    task cpu_read;
        input [31:0] address;
        begin
            @(negedge clk);
            cpu_addr = address;
            cpu_req = 1;

            @(negedge clk);
            cpu_req = 0;

            wait(cpu_ready);
            #1;

            $display("CPU read %h -> %h",
                     address, cpu_rdata);
        end
    endtask

    initial begin

        clk = 0;
        rst = 1;

        cpu_req = 0;
        cpu_addr = 0;

        total_dram_requests = 0;
        total_prefetch_requests = 0;
        total_prefetch_hits = 0;
        total_cache_hits = 0;
        total_cache_misses = 0;

        repeat (3) @(negedge clk);
        rst = 0;

        $display("\n--- SEQUENTIAL ACCESS TEST ---");

        for (i = 0; i < 12; i = i + 1) begin
            cpu_read(32'h00001000 + i*16);
        end

        $display("\n--- REPEATED ACCESS TEST ---");

        cpu_read(32'h00001000);
        cpu_read(32'h00001000);
        cpu_read(32'h00001000);

        $display("\n--- SIMULATION COMPLETE ---");

        #100;
        $display("\n--- PERFORMANCE RESULTS ---");

$display("DRAM requests       = %0d", total_dram_requests);
$display("Prefetch issued     = %0d", total_prefetch_requests);
$display("Prefetch hits       = %0d", total_prefetch_hits);
$display("Cache hits          = %0d", total_cache_hits);
$display("Cache misses        = %0d", total_cache_misses);
$display("Duplicate predictions = %0d",
         dut.duplicate_count);
        $finish;
    end
always @(posedge clk) begin
    if (!rst) begin

        if (dut.dram_req && !dut.dram_busy)
            total_dram_requests <= total_dram_requests + 1;

        if (dut.prefetch_accept)
            total_prefetch_requests <=
                total_prefetch_requests + 1;

        if (dut.cache.prefetch_hit_count != 0)
            total_prefetch_hits <=
                dut.cache.prefetch_hit_count;

        total_cache_hits <= dut.cache.hit_count;
        total_cache_misses <= dut.cache.miss_count;

    end
end



always @(posedge clk) begin
    if (!rst) begin

        if (dut.access_valid)
            $display("[CPU ACCESS] line=%h",
                     dut.access_line);

        if (dut.predictor_valid)
            $display("[PREDICT] line=%h",
                     dut.predictor_line);

        if (dut.prefetch_req)
            $display("[PREFETCH REQUEST] address=%h",
                     dut.prefetch_addr);

        if (dut.prefetch_accept)
            $display("[PREFETCH ACCEPTED] address=%h",
                     dut.prefetch_addr);

        if (dut.prefetch_resp_valid)
            $display("[PREFETCH RESPONSE]");

        if (dut.pb_insert)
            $display("[BUFFER INSERT] line=%h",
                     dut.pb_insert_line);

        if (dut.pb_lookup)
            $display("[BUFFER LOOKUP] line=%h",
                     dut.pb_lookup_line);

        if (dut.pb_hit)
            $display("[BUFFER HIT] line=%h",
                     dut.pb_lookup_line);

    end
end

endmodule
