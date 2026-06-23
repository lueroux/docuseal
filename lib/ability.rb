# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end

    can :destroy, Template, account_id: user.account_id
    can :manage, TemplateFolder, account_id: user.account_id
    can :manage, TemplateSharing, template: { account_id: user.account_id }
    can :manage, Submission, account_id: user.account_id
    can :manage, Submitter, account_id: user.account_id
    can :manage, User, account_id: user.account_id
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id
    can :manage, Company, account_id: user.account_id
    can :manage, Customer, account_id: user.account_id
    can :manage, CustomerPricingTerm, customer: { account_id: user.account_id }
    can :manage, Product, account_id: user.account_id
    can :manage, ProductOption, product: { account_id: user.account_id }
    can :manage, ProductCompatibilityRule, product: { account_id: user.account_id }
    can :manage, Quote, account_id: user.account_id
    can :manage, QuoteItem, quote: { account_id: user.account_id }
    can :create, QuoteItem
    can :manage, QuoteItemOption, quote_item: { quote: { account_id: user.account_id } }
    can :manage, QuoteSection, quote: { account_id: user.account_id }
    can :manage, QuotePaymentStructure, quote: { account_id: user.account_id }

    can :manage, :mcp
  end
end
