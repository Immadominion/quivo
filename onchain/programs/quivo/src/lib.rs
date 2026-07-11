//! Quivo — the money + fairness layer for a live game show.
//!
//! Gameplay (timing, secret questions, scoring, leaderboard) is authoritative OFF-chain in the
//! Colyseus server. This program owns only what must be trustless:
//!   * the prize pot, held in a program-owned escrow (the host cannot withdraw it),
//!   * a commitment to the question set (so questions can't be swapped after money is staked),
//!   * settlement: verify the reveal and pay the podium from escrow (base layer).
//!
//! Tier-1 (shipped): escrow + question commit-reveal + base-layer settle payout — the game is NOT
//! delegated, so settle needs no ER. Tier-2 (delegate the game + `submit_answer` on the ER, then a
//! commit + Magic-Action payout) is the live-answer-anchoring path that makes the ER load-bearing;
//! `delegate_game`/`submit_answer` are wired for it. `#[ephemeral]` stays for both.
//!
//! Placeholder program id — run `anchor keys sync` after the first `anchor build`.
use anchor_lang::prelude::*;
use solana_keccak_hasher as keccak;
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};
use ephemeral_rollups_sdk::anchor::{delegate, ephemeral};
use ephemeral_rollups_sdk::cpi::DelegateConfig;

declare_id!("BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG");

pub const GAME_SEED: &[u8] = b"game";
pub const VAULT_SEED: &[u8] = b"vault";
pub const PLAYER_SEED: &[u8] = b"player";
pub const MAX_QUESTIONS: usize = 16;
pub const UNANSWERED: u8 = 0xFF;

pub mod status {
    pub const LOBBY: u8 = 0;
    pub const ACTIVE: u8 = 1;
    pub const SETTLING: u8 = 2;
    pub const COMPLETE: u8 = 3;
}

#[ephemeral]
#[program]
pub mod quivo {
    use super::*;

    /// Create the game + its escrow vault. `prize_split` must sum to 100 (e.g. [60,30,10]).
    pub fn initialize_game(
        ctx: Context<InitializeGame>,
        seed: u64,
        num_questions: u8,
        prize_split: [u8; 3],
    ) -> Result<()> {
        require!(
            (num_questions as usize) <= MAX_QUESTIONS && num_questions > 0,
            QuivoError::BadQuestionCount
        );
        require!(
            prize_split.iter().map(|p| *p as u16).sum::<u16>() == 100,
            QuivoError::BadPrizeSplit
        );
        let g = &mut ctx.accounts.game;
        g.host = ctx.accounts.host.key();
        g.pot_mint = ctx.accounts.pot_mint.key();
        g.pot_vault = ctx.accounts.pot_vault.key();
        g.status = status::LOBBY;
        g.question_commitment = [0u8; 32];
        g.num_questions = num_questions;
        g.prize_split = prize_split;
        g.players = 0;
        g.answers_root = [0u8; 32];
        g.seed = seed;
        g.bump = ctx.bumps.game;
        g.vault_bump = ctx.bumps.vault_authority;
        Ok(())
    }

    /// Move prize funds into escrow. Anyone (host or a sponsor) may fund.
    pub fn fund_pot(ctx: Context<FundPot>, amount: u64) -> Result<()> {
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.key(),
                Transfer {
                    from: ctx.accounts.funder_ata.to_account_info(),
                    to: ctx.accounts.pot_vault.to_account_info(),
                    authority: ctx.accounts.funder.to_account_info(),
                },
            ),
            amount,
        )
    }

    /// Commit `keccak256(questions ‖ answers ‖ salt)` BEFORE any player joins. Host only, lobby only.
    pub fn commit_questions(ctx: Context<HostOnly>, commitment: [u8; 32]) -> Result<()> {
        let g = &mut ctx.accounts.game;
        require!(g.status == status::LOBBY, QuivoError::WrongPhase);
        g.question_commitment = commitment;
        Ok(())
    }

    /// Register a player (their own PDA — no shared-account contention when we lift to Tier-2).
    pub fn join_game(ctx: Context<JoinGame>) -> Result<()> {
        let p = &mut ctx.accounts.player;
        p.game = ctx.accounts.game.key();
        p.wallet = ctx.accounts.wallet.key();
        p.score = 0;
        p.answered_count = 0;
        p.prized = false;
        p.bump = ctx.bumps.player;
        p.choices = [UNANSWERED; MAX_QUESTIONS];
        p.buckets = [0u8; MAX_QUESTIONS];
        ctx.accounts.game.players += 1;
        Ok(())
    }

    /// Delegate the game account to the ER validator for the duration of play.
    /// Commit once at settlement (not per answer): pass `commit_frequency_ms = u32::MAX`.
    pub fn delegate_game(ctx: Context<DelegateGame>, seed: u64) -> Result<()> {
        let host = ctx.accounts.host.key();
        let seed_le = seed.to_le_bytes();
        ctx.accounts.delegate_game(
            &ctx.accounts.host,
            &[GAME_SEED, host.as_ref(), &seed_le],
            DelegateConfig {
                commit_frequency_ms: u32::MAX,
                validator: ctx.remaining_accounts.first().map(|a| a.key()),
            },
        )?;
        Ok(())
    }

    /// TIER-2 — runs on the ER, session-key-signed, gasless. Records a player's answer so scoring is
    /// reconstructible on-chain. Tier-1 leaves scoring to the server + a Merkle root; this is the lift.
    pub fn submit_answer(
        ctx: Context<SubmitAnswer>,
        question_index: u8,
        choice: u8,
        bucket: u8,
    ) -> Result<()> {
        let qi = question_index as usize;
        require!(qi < ctx.accounts.game.num_questions as usize, QuivoError::BadQuestionIndex);
        let p = &mut ctx.accounts.player;
        require!(p.choices[qi] == UNANSWERED, QuivoError::AlreadyAnswered);
        p.choices[qi] = choice;
        p.buckets[qi] = bucket;
        p.answered_count += 1;
        Ok(())
    }

    /// Post the Merkle root of all answers (Tier-1 auditability) and move to settling.
    pub fn close_and_root(ctx: Context<HostOnly>, answers_root: [u8; 32]) -> Result<()> {
        let g = &mut ctx.accounts.game;
        g.answers_root = answers_root;
        g.status = status::SETTLING;
        Ok(())
    }

    /// Settle (Tier-1, base layer): verify the question reveal against the commitment, then pay the
    /// podium from escrow. Winners' token accounts are passed as `remaining_accounts` in podium order
    /// (1st..=Nth); the off-chain server computes the ranking. No ER — the game is never delegated in
    /// Tier-1, so the transfers happen directly on base layer.
    pub fn settle<'info>(
        ctx: Context<'info, Settle<'info>>,
        reveal: Vec<u8>,
    ) -> Result<()> {
        let (game_key, vault_bump, prize_split, pot_mint) = {
            let g = &ctx.accounts.game;
            require!(g.status != status::COMPLETE, QuivoError::WrongPhase);
            // Fairness: the revealed question set must match the pre-committed hash.
            let h = keccak::hash(&reveal).to_bytes();
            require!(h == g.question_commitment, QuivoError::RevealMismatch);
            (g.key(), g.vault_bump, g.prize_split, g.pot_mint)
        };

        // Pay the podium from escrow. Amounts = split% of the vault balance; remainder → 1st place.
        let pot = ctx.accounts.pot_vault.amount;
        let signer_seeds: &[&[u8]] = &[VAULT_SEED, game_key.as_ref(), &[vault_bump]];
        for (i, winner_ata) in ctx.remaining_accounts.iter().enumerate().take(prize_split.len()) {
            let amount = if i == 0 {
                let others: u64 = prize_split.iter().skip(1).map(|p| pot.saturating_mul(*p as u64) / 100).sum();
                pot.saturating_sub(others) // rounding remainder → first place
            } else {
                pot.saturating_mul(prize_split[i] as u64) / 100
            };
            // Guard: the winner account must be an SPL token account for THIS pot's mint.
            {
                let data = winner_ata.try_borrow_data()?;
                let ta = TokenAccount::try_deserialize(&mut &data[..])?;
                require_keys_eq!(ta.mint, pot_mint, QuivoError::WrongMint);
            }
            token::transfer(
                CpiContext::new_with_signer(
                    ctx.accounts.token_program.key(),
                    Transfer {
                        from: ctx.accounts.pot_vault.to_account_info(),
                        to: winner_ata.to_account_info(),
                        authority: ctx.accounts.vault_authority.to_account_info(),
                    },
                    &[signer_seeds],
                ),
                amount,
            )?;
        }

        ctx.accounts.game.status = status::COMPLETE;
        Ok(())
    }
}

// ─────────────────────────── State ───────────────────────────

#[account]
#[derive(InitSpace)]
pub struct Game {
    pub host: Pubkey,
    pub pot_mint: Pubkey,
    pub pot_vault: Pubkey,
    pub status: u8,
    pub question_commitment: [u8; 32],
    pub num_questions: u8,
    pub prize_split: [u8; 3],
    pub players: u32,
    pub answers_root: [u8; 32],
    pub seed: u64,
    pub bump: u8,
    pub vault_bump: u8,
}

#[account]
#[derive(InitSpace)]
pub struct Player {
    pub game: Pubkey,
    pub wallet: Pubkey,
    pub score: u64,
    pub answered_count: u16,
    pub prized: bool,
    pub bump: u8,
    pub choices: [u8; MAX_QUESTIONS],
    pub buckets: [u8; MAX_QUESTIONS],
}

// ─────────────────────────── Accounts ───────────────────────────

#[derive(Accounts)]
#[instruction(seed: u64)]
pub struct InitializeGame<'info> {
    #[account(mut)]
    pub host: Signer<'info>,
    #[account(
        init, payer = host, space = 8 + Game::INIT_SPACE,
        seeds = [GAME_SEED, host.key().as_ref(), &seed.to_le_bytes()], bump
    )]
    pub game: Account<'info, Game>,
    pub pot_mint: Account<'info, Mint>,
    /// CHECK: PDA that owns the escrow vault; validated by seeds.
    #[account(seeds = [VAULT_SEED, game.key().as_ref()], bump)]
    pub vault_authority: UncheckedAccount<'info>,
    #[account(
        init, payer = host,
        associated_token::mint = pot_mint,
        associated_token::authority = vault_authority
    )]
    pub pot_vault: Account<'info, TokenAccount>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct FundPot<'info> {
    #[account(mut)]
    pub funder: Signer<'info>,
    #[account(mut)]
    pub funder_ata: Account<'info, TokenAccount>,
    #[account(mut, address = game.pot_vault)]
    pub pot_vault: Account<'info, TokenAccount>,
    pub game: Account<'info, Game>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct HostOnly<'info> {
    #[account(address = game.host)]
    pub host: Signer<'info>,
    #[account(mut)]
    pub game: Account<'info, Game>,
}

#[derive(Accounts)]
pub struct JoinGame<'info> {
    #[account(mut)]
    pub wallet: Signer<'info>,
    #[account(mut)]
    pub game: Account<'info, Game>,
    #[account(
        init, payer = wallet, space = 8 + Player::INIT_SPACE,
        seeds = [PLAYER_SEED, game.key().as_ref(), wallet.key().as_ref()], bump
    )]
    pub player: Account<'info, Player>,
    pub system_program: Program<'info, System>,
}

/// `#[delegate]` injects the `delegate_game(...)` helper + the delegation CPI accounts.
#[delegate]
#[derive(Accounts)]
#[instruction(seed: u64)]
pub struct DelegateGame<'info> {
    #[account(mut, address = game_pda.host)]
    pub host: Signer<'info>,
    /// CHECK: the PDA being delegated; seeds enforced by the delegate CPI.
    #[account(mut, del)]
    pub game: UncheckedAccount<'info>,
    /// Read-only view to authorize the host (the delegated account is Unchecked above).
    #[account(seeds = [GAME_SEED, host.key().as_ref(), &seed.to_le_bytes()], bump)]
    pub game_pda: Account<'info, Game>,
}

#[derive(Accounts)]
pub struct SubmitAnswer<'info> {
    /// Session key or the player's own wallet (scoped, gasless on the ER).
    pub signer: Signer<'info>,
    pub game: Account<'info, Game>,
    #[account(mut, has_one = game)]
    pub player: Account<'info, Player>,
}

#[derive(Accounts)]
pub struct Settle<'info> {
    #[account(mut, address = game.host)]
    pub payer: Signer<'info>,
    #[account(mut)]
    pub game: Account<'info, Game>,
    /// CHECK: escrow authority PDA; validated by seeds.
    #[account(seeds = [VAULT_SEED, game.key().as_ref()], bump = game.vault_bump)]
    pub vault_authority: UncheckedAccount<'info>,
    #[account(mut, address = game.pot_vault)]
    pub pot_vault: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    // remaining_accounts: winners' token accounts, in podium order.
}

// ─────────────────────────── Errors ───────────────────────────

#[error_code]
pub enum QuivoError {
    #[msg("question count must be 1..=MAX_QUESTIONS")]
    BadQuestionCount,
    #[msg("prize split must sum to 100")]
    BadPrizeSplit,
    #[msg("wrong game phase for this action")]
    WrongPhase,
    #[msg("question index out of range")]
    BadQuestionIndex,
    #[msg("this question was already answered")]
    AlreadyAnswered,
    #[msg("revealed questions do not match the commitment")]
    RevealMismatch,
    #[msg("winner token account is not for the pot mint")]
    WrongMint,
}
