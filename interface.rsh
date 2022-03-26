"reach 0.1";
"use strict";
// -----------------------------------------------
// Name: Interface Template
// Description: NP Rapp simple
// Author: Nicholas Shellabarger
// Version: 0.0.2 - initial
// Requires Reach v0.1.7 (stable)
// ----------------------------------------------
export const Participants = () => [
  Participant("Attendee", {
    getParams: Fun(
      [],
      Object({
        admin: Address,
        token: Token,
        price: UInt,
        ctcEvent: Contract
      })
    ),
    signal: Fun([], Null)
  }),
];
export const Views = () => [
  View({
    attendee: Address,
    admin: Address,
    ticket: Token,
    attending: Bool,
    granted: Bool,
    balance: UInt
  }),
];
export const Api = () => [
  API({
    check: Fun([], Null),
    peerCheck: Fun([], Null),
    touch: Fun([], Null),
    grant: Fun([], Null),
    destroy: Fun([], Null),
  }),
];
export const App = (map) => {
  const [[Attendee], [v], [a]] = map;
  Attendee.only(() => {
    const { admin, token, ctcEvent, price } = declassify(interact.getParams());
  });
  Attendee.publish(admin, token, ctcEvent, price).pay(price);
  Attendee.interact.signal();
  const r = remote(ctcEvent, {
    incr: Fun([], Null)
  });
  r.incr();
  v.attendee.set(Attendee);
  v.admin.set(admin);
  v.ticket.set(token);
  v.attending.set(false);
  v.granted.set(false);
  v.balance.set(0);
  const [keepGoing, attending, allowPeerCheck, bal] = parallelReduce([true, false, false, 0])
    .define(() => {
      v.attending.set(attending);
      v.granted.set(allowPeerCheck);
      v.balance.set(bal);
    })
    .invariant(balance() >= 0 && balance(token) >= 0)
    .while(keepGoing)
    .api(
      a.check,
      () => assume(this == admin && attending == false),
      () => [0, [1, token]],
      (k) => {
        require(this == admin && attending == false);
        k(null);
        return [true, true, allowPeerCheck, 1];
      }
    )
    .api(
      a.peerCheck,
      () => assume(allowPeerCheck == true),
      () => [100000, [1, token]],
      (k) => {
        require(allowPeerCheck == true);
        transfer(balance(token), token).to(this)
        k(null);
        return [true, true, true, 0];
      }
    )
    .api(
      a.grant,
      () => assume(this == Attendee && balance(token) == 0 && attending == false),
      () => [100000, [0, token]],
      (k) => {
        require(this == Attendee && balance(token) == 0 && attending == false);
        k(null);
        return [true, false, true, 0];
      }
    )
    .api(
      a.touch,
      () => assume(this == Attendee && balance(token) > 0 && attending === true),
      () => [100000, [0, token]],
      (k) => {
        require(this == Attendee && balance(token) > 0 && attending === true);
        transfer(1, token).to(this)
        k(null);
        return [true, true, true, 0];
      }
    )
    .api(
      a.destroy,
      () => assume(this == Attendee),
      () => [100000, [0, token]],
      (k) => {
        require(this == Attendee);
        k(null);
        return [false, attending, allowPeerCheck, bal];
      }
    )
    .timeout(false);
  if(balance(token) == 0) {
    transfer(balance()-100000).to(Attendee);
    transfer(100000).to(admin);
  } else {
    transfer(balance()).to(Attendee);
  }
  transfer(balance(token), token).to(admin);
  commit();
  exit();
};
// ----------------------------------------------
