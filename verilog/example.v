// DESCRIPTION: Example top verilog file for vpassert program
// This file ONLY is placed into the Public Domain, for any use,
// without warranty, 2000-2012 by Wilson Snyder.

`timescale 1ns/1ns

module example;

   pli pli ();	// Put on highest level of your design

   integer i;

`define ten 10

   reg \escaped[10] ;

   initial begin
      $uinfo (0, "Welcome to a VPASSERTed file\n");
      //
      $uinfo (1, "Printed only at debug level %0d\n",1);
      $uinfo (9, "Printed only at debug level %0d\n",9);
      //
      \escaped[10] = 1'b1;
      $uassert (\escaped[10] , "Escaped not 1\n");
      $uassert_info (\escaped[10] , "Escaped not 1\n");
      //
      i=0;
      $uassert (1==1, "Why doesn't 1==1??\n");
      $uassert (10==`ten, "Why doesn't 10==10??\n");
      $uassert (/*comm
		ent*/1==1,
	       //comment
	       /*com
		ent*/"Why doesn't 1==1??\n"/*com
	       ent*/
	       );
      //
      i=3'b100;  $uassert_amone(\i [2:0], "amone ok\n");
      i=3'b010;  $uassert_amone(i[2:0], "amone ok\n");
      i=3'b001;  $uassert_amone(i[2:0], "amone ok\n");
      i=3'b000;  $uassert_amone(i[2:0], "amone ok\n");
      //i=3'b011;  $uassert_amone(i[2:0], "amone error expected\n");
      //i=3'b110;  $uassert_amone(i[2:0], "amone error expected\n");
      //
      i=2'b10;  $uassert_onehot(i[1:0], "onehot ok\n");
      i=2'b01;  $uassert_onehot(i[1:0], "onehot ok\n");
      i=2'b10;  $uassert_onehot(i[1],i[0], "onehot ok\n");
      i=2'b10;  $uassert_onehot({i[1],i[0]}, "onehot ok\n");
      //i=2'b11;  $uassert_onehot(i[2:0], "onehot error expected\n");
      //i=2'b00;  $uassert_onehot(i[2:0], "onehot error expected\n");
   end

   // Test assertions within case statements
   initial begin
      i=3'b100;
      casez (i)
	3'b100: ;
	3'b000: $stop;
	3'b010: $uerror("Why?\n");
	default: $stop;
      endcase
      if ($time > 1000) $stop;
   end

   // Example of request/grant handshake
   reg	      clk;
   reg	      bus_req;		// Request a transaction, single cycle pulse
   reg	      bus_ack;		// Acknowledged transaction, single cycle pulse
   reg [31:0] bus_data;

   initial begin
      // Reset signals
      bus_req  = 1'b0;
      bus_ack  = 1'b0;
      bus_data = 1'b0;
      // Assert a request
      @ (posedge clk) ;
      bus_req  = 1'b1;
      bus_data = 32'hfeed;
      // Wait for ack
      @ (posedge clk) ;
      bus_req  = 1'b0;
      // Send ack
      @ (posedge clk) ;
      bus_ack  = 1'b1;
      // Next request could be here
      @ (posedge clk) ;
      bus_ack  = 1'b0;
   end
   always @ (posedge clk) begin
      $uassert_req_ack (bus_req,
			bus_ack /*COMMENT*/,
			bus_data);
   end

   // Overall control loop
   initial clk = 1'b0;
   initial forever begin
      #1;
      i = i + 1;
      clk = !clk;
      if (i==20) $uwarn  (0, "Don't know what to do next!\n");
      if (i==22) $uerror (0, "Guess I'll error out!\n");
   end

   // Moved clock asserts
   always @* begin
      if (i==19) $uwarn_clk  (clk,"Called at next edge (1 of 2)\n");
      if (i==18) $ucover_clk (clk,"example_cover_label");
      $ucover_foreach_clk(clk, "foreach_label", "27:3,1,0", (i[$ui]));
   end

   // Meta coverage disables
   initial begin
      // vp_coverage_off
      if (0) begin end // cover off'ed
      // vp_coverage_on
   end

   // Ifdef based disables
   initial begin
`ifndef NEVER
 `ifdef SYNTHESIS
      if (1) begin end  // cover on
 `elsif SYNTHESIS
      if (1) begin end  // cover on
 `else
      if (1) begin end  // cover off'ed
 `endif
 `ifndef SYNTHESIS
      if (1) begin end  // cover off'ed
 `else
      if (1) begin end  // cover on
 `endif
`endif
    end

endmodule
