# 💼 Freelancer Escrow Contract

A secure smart contract for freelancing payments on the Stacks blockchain that locks funds until work is completed and approved.

## 🚀 Features

- 🔒 **Secure Escrow**: Lock funds until work completion
- ✅ **Work Approval System**: Client approval required for payment release
- 🛡️ **Dispute Resolution**: Built-in arbitration system
- ⏰ **Emergency Release**: Automatic release after deadline expiry
- 💰 **Platform Fees**: Configurable fee structure
- 🔄 **Multiple Statuses**: Track project progress through various stages

## 📋 Contract Status Flow

```
Pending → Funded → Submitted → Approved/Rejected → Completed/Cancelled
                     ↓
                 Disputed → Resolved
```

## 🎯 Core Functions

### For Clients 👤

#### `create-escrow`
Create a new escrow agreement with a freelancer.
```clarity
(create-escrow freelancer-address amount "Project description" deadline-block)
```

#### `fund-escrow` 
Fund the escrow with STX tokens.
```clarity
(fund-escrow escrow-id)
```

#### `approve-work`
Approve completed work and release payment to freelancer.
```clarity
(approve-work escrow-id)
```

#### `reject-work`
Reject work and get refund.
```clarity
(reject-work escrow-id)
```

### For Freelancers 💻

#### `submit-work`
Submit completed work for client review.
```clarity
(submit-work escrow-id)
```

#### `emergency-release`
Release funds after deadline expires (if work was submitted).
```clarity
(emergency-release escrow-id)
```

### For Both Parties ⚖️

#### `raise-dispute`
Raise a dispute if there's disagreement.
```clarity
(raise-dispute escrow-id "Dispute reason")
```

## 🔧 Usage Example

1. **Client creates escrow:**
   ```clarity
   (create-escrow 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 1000000 "Website redesign project" u144000)
   ```

2. **Client funds escrow:**
   ```clarity
   (fund-escrow u1)
   ```

3. **Freelancer submits work:**
   ```clarity
   (submit-work u1)
   ```

4. **Client approves and releases payment:**
   ```clarity
   (approve-work u1)
   ```

## 📊 Status Codes

- `1` - Pending (created but not funded)
- `2` - Funded (ready for work)
- `3` - Submitted (work delivered, awaiting approval)
- `4` - Approved (work approved, not used directly)
- `5` - Disputed (dispute raised)
- `6` - Cancelled (escrow cancelled/refunded)
- `7` - Completed (payment released)

## 🔍 Read-Only Functions

- `get-escrow` - Get escrow details
- `get-user-balance` - Check user balance
- `get-platform-fee-rate` - Current platform fee rate
- `calculate-platform-fee` - Calculate fee for amount
- `is-expired` - Check if escrow deadline passed

## ⚙️ Admin Functions

#### `resolve-dispute`
Resolve disputes and award funds (contract owner only).
```clarity
(resolve-dispute escrow-id "Resolution details" award-to-freelancer)
```

#### `set-platform-fee-rate`
Update platform fee rate (contract owner only).
```clarity
(set-platform-fee-rate new-rate-basis-points)
```

## 💸 Platform Fees

- Default fee: 2.5% (250 basis points)
- Fees are deducted from freelancer payment
- Configurable by contract owner

## 🛡️ Security Features

- ✅ Authorization checks for all operations
- ✅ Status validation to prevent invalid transitions
- ✅ Deadline enforcement
- ✅ Dispute resolution mechanism
- ✅ Emergency release after expiry

## 🚨 Error Codes

- `u100` - Owner only operation
- `u101` - Escrow not found
- `u102` - Unauthorized access
- `u103` - Invalid status for operation
- `u104` - Insufficient funds
- `u105` - Already exists
- `u106` - Escrow expired
- `u107` - Escrow not expired
- `u108` - Invalid amount

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

Check contract syntax:
```bash
clarinet check
```

## 📦 Deployment

1. Deploy to testnet:
   ```bash
   clarinet publish --testnet
   ```

2. Deploy to mainnet:
   ```bash
   clarinet publish --mainnet
   ```



## 📄 License

This project is licensed under the MIT License.

---

Built with ❤️ on Stacks blockchain
